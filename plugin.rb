# name: CWHQ-Discourse-Bot
# about: This plugin adds extra functionality to the @system user on a Discourse forum.
# version: 1.9.0
# authors: Qursch, bronze0202, linuxmasters, sep208, Astr0clad, usrbinsam, daniel-schroeder-dev, sharpkeen, shriyash-shukla
# url: https://github.com/codewizardshq/CWHQ-Discourse-Bot

# Require the 'date' library for handling date and time operations
require 'date'

# Initialize an empty hash to store course IDs and their corresponding URLs
courses = Hash.new

# Populate the hash with course IDs and their corresponding URLs or identifiers
courses = {
    11 => "https://scratch.mit.edu/projects/00000000/",
    57 => "https://scratch.mit.edu/projects/00000000/",
    85 => "e13_text_prog_00",
    36 => "e13_real_prog_00",
    37 => "e14_minecraft_00",
    90 => "e20_prog_fundamentals_00",
    45 => "e21_prog_concepts_00",
    31 => "e22_wd1_00",
    58 => "e23_wd2_00",
    46 => "e24_python_game_dev_00",
    13 => "m112_intro_prog_py_00",
    84 => "m12_python_beyond_basics_00",
    14 => "m13_html_css_00",
    15 => "m13_js_00",
    16 => "M14_vr_00",
    89 => "m21_resp_web_dev_00",
    17 => "m21_ui_00",
    18 => "m22_database_00",
    47 => "m23_api_00",
    48 => "m24_omg_00",
    20 => "h112_intro_python_00",
    21 => "h12_web_dev_00",
    22 => "h13_ui_00",
    73 => "h14_capstone_00",
    23 => "h21_api_00",
    49 => "h22_web_app_00",
    74 => "h23_css_framework_00",
    52 => "h24_capstone_00",
    50 => "h31_mvc_00",
    51 => "h32_orm_00",
    75 => "h33_devops_00",
    76 => "h34_capstone_00"
}

# Function to get the project link based on course ID and username
def get_link(id, username, hash)
    # Check if the course ID matches specific IDs that use a fixed URL
    if id == 11 || id == 57
        return "`https://scratch.mit.edu/projects/00000000`" 
    else
        # If the course ID is found in the hash and is specifically 'm112_intro_prog_py_00'
        if !hash[id].nil? && hash[id] == "m112_intro_prog_py_00"
            return "`https://#{username}.codewizardshq.com/#{hash[id]}/project` or `https://#{username}.codewizardshq.com/#{hash[id]}/project-folder`"
        elsif !hash[id].nil?
            return "`https://#{username}.codewizardshq.com/#{hash[id]}/project`"
        end
    end
    # Return false if no link is found
    return false
end

# Function to create a post in a given topic with the specified text
def create_post(topicId, text)
    post = PostCreator.create(
        Discourse.system_user, # The system user who creates the post
        skip_validations: true, # Skip validations for the post
        topic_id: topicId, # The ID of the topic where the post will be created
        raw: text # The content of the post
    )
    # Save the post if it was successfully created
    unless post.nil?
        post.save(validate: false)
    end
end

# Function to close a topic with a given message
def closeTopic(id, message)
    topic = Topic.find_by(id: id) # Find the topic by its ID
    # Update the topic status to closed and add a message
    topic.update_status("closed", true, Discourse.system_user, { message: message })
    author_username = topic.user.username # Get the username of the topic author
    send_pm_to_author(author_username, id, message) # Send a private message to the author
end

# Function to check if the topic title includes specific URLs
def check_title(title)
    if title.downcase.include?("codewizardshq.com") || title.downcase.include?("scratch.mit.edu")
        return true
    else
        return false
    end
end

# Function to check if the text contains valid link types
def check_all_link_types(text)
    if (text.include?("codewizardshq.com") && !text.include?("/edit")) || (text.include?("cwhq-apps") || text.include?("scratch.mit.edu"))
        return true
    end
end

# Function to log commands in a specific topic
def log_command(command, link, name)
    log_topic_id = 11303 # The ID of the topic where logs are posted
    text = "@#{name} #{command}:<br>#{link}" # Format the log message
    create_post(log_topic_id, text) # Create a post in the log topic
end

# Function to send a private message to a user
def send_pm(title, text, user)
    message = PostCreator.create!(
        Discourse.system_user, # The system user who sends the message
        title: title, # The title of the message
        raw: text, # The content of the message
        archetype: Archetype.private_message, # Set the message type to private
        target_usernames: user, # The recipient username
        skip_validations: true # Skip validations for the message
    )
end

# Function to send a private message to the author when a topic is closed
def send_pm_to_author(author_username, topic_id, message)
    title = "Your topic (ID: #{topic_id}) has been closed" # The title of the message
    text = "Hello @#{author_username},\n\nYour topic (ID: #{topic_id}) has been closed. Reason: #{message}\n\nIf you have any questions or need further assistance, feel free to reach out to us.\n\nBest regards,\nThe CodeWizardsHQ Team" # The content of the message
    send_pm(title, text, author_username) # Send the message
end

# Hook to initialize plugin behavior after Discourse has started
after_initialize do
    # Event handler for when a topic is created
    DiscourseEvent.on(:topic_created) do |topic| 
        newTopic = Post.find_by(topic_id: topic.id, post_number: 1) # Find the first post in the topic
        topicRaw = newTopic.raw # Get the raw content of the first post
        lookFor = topic.user.username + ".codewizardshq.com" # Generate the link prefix to look for
        # Retrieve the project link based on category ID and username
        link = get_link(topic.category_id, topic.user.username, courses)
        # Check if the link is valid and not an editor link
        if link then
            if topicRaw.downcase.include?(lookFor + "/edit") then
                text = "Hello @#{topic.user.username}, it appears that the link you provided goes to the editor, and not your project. Please open your project and use the link from that tab. This may look like " + link + "."
                create_post(topic.id, text) # Create a post with the message
                log_command("received an editor link message", "https://forum.codewizardshq.com/t/#{topic.topic_id}", topic.user.username) # Log the command
            elsif !topicRaw.downcase.include?(lookFor) && !topicRaw.downcase.include?("cwhq-apps.com") then
                text = "Hello @#{topic.user.username}, it appears that you did not provide a link to your project. In order to receive the best help, please edit your topic to contain a link to your project. This may look like " + link + "."
                create_post(topic.id, text) # Create a post with the message
                log_command("received a missing link message", "https://forum.codewizardshq.com/t/#{topic.topic_id}", topic.user.username) # Log the command
            end
        end

        topic_title = topic.title # Get the title of the topic
        
        # Check if the topic title contains specific URLs
        if check_title(topic_title) then
            text = "Hello @#{topic.user.username}, it appears you provided a link in your topic's title. Please change the title of this topic to something that clearly explains what the topic is about. This will help other forum users know what you want to show or get help with. You can edit your topic title by pressing the pencil icon next to the current one. Be sure to put the link in the main body of your post."
            if topicRaw.downcase.include?(lookFor) || topicRaw.downcase.include?("scratch.mit.edu") then
                create_post(topic.id, text) # Create a post with the message
                log_command("received a link in title message", "https://forum.codewizardshq.com/t/#{topic.topic_id}", topic.user.username) # Log the command
            end
        end

        # Check if the topic has a valid link or text
        if check_all_link_types(topicRaw) then
            log_command("received valid link message", "https://forum.codewizardshq.com/t/#{topic.topic_id}", topic.user.username) # Log the command
        end
    end

    # Event handler for when a post is created
    DiscourseEvent.on(:post_created) do |post| 
        # Only handle posts created in the 'course-announcements' topic
        if post.topic_id == 10635 then
            if post.user.username.downcase == 'system' then
                text = post.raw # Get the content of the post
                match = /([\w.]+) @ ([\d]+) ([\w.]+) \((.*)\) \n\n(.*)/.match(text) # Match specific patterns in the text
                if match then
                    user = match[1] # Extract the user
                    id = match[2].to_i # Extract the ID
                    name = match[3] # Extract the name
                    message = match[5] # Extract the message
                    link = get_link(id, user, courses) # Get the project link
                    if !link then
                        link = get_link(id, user, courses)
                    end
                    if !link then
                        text = "There is an issue with the link for course ID #{id}. Please check the course ID and try again."
                        create_post(post.topic_id, text) # Create a post with the error message
                    else
                        if post.raw.include?("not found") then
                            text = "I cannot find your project. Please make sure you have shared the correct link."
                            create_post(post.topic_id, text) # Create a post with the error message
                        end
                        log_command("validated link", link, user) # Log the command
                        create_post(post.topic_id, "#{link}<br>#{message}") # Create a post with the project link and message
                    end
                end
            end
        end
    end

    # Event handler for when a topic is updated
    DiscourseEvent.on(:topic_updated) do |topic|
        if topic.id == 11600 then
            if topic.user.username == "Discourse" then
                if topic.last_post.raw.include?("CWHQ-GU-") then
                    create_post(topic.id, "Link is now valid") # Create a post with the validation message
                end
            end
        end
    end
end
