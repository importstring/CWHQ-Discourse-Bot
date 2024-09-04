# CWHQ-Discourse-Bot Plugin
# This plugin adds extra functionality to the @system user on a Discourse forum.

require 'date'

# Hash of course IDs mapped to their respective URLs or identifiers
courses = Hash.new
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

# Retrieve a link based on the course ID and username
# @param id [Integer] the course ID
# @param username [String] the username of the course author
# @param hash [Hash] the hash containing course IDs and their corresponding URLs or identifiers
# @return [String, FalseClass] the link to the course project or false if no valid link is found
def get_link(id, username, hash)
    if id == 11 || id == 57
        return "`https://scratch.mit.edu/projects/00000000`"
    else
        if !hash[id].nil? && hash[id] == "m112_intro_prog_py_00"
            return "`https://#{username}.codewizardshq.com/#{hash[id]}/project` or `https://#{username}.codewizardshq.com/#{hash[id]}/project-folder`"
        elsif !hash[id].nil?
            return "`https://#{username}.codewizardshq.com/#{hash[id]}/project`"
        end
    end
    return false
end

# Create a post in a specified topic
# @param topicId [Integer] the ID of the topic where the post should be created
# @param text [String] the content of the post
def create_post(topicId, text)
    post = PostCreator.create(
        Discourse.system_user,
        skip_validations: true,
        topic_id: topicId,
        raw: text
    )
    unless post.nil?
        post.save(validate: false)
    end
end

# Close a topic and notify the author
# @param id [Integer] the ID of the topic to be closed
# @param message [String] the reason for closing the topic
def closeTopic(id, message)
    topic = Topic.find_by(id: id)
    topic.update_status("closed", true, Discourse.system_user, { message: message })
    author_username = topic.user.username
    send_pm_to_author(author_username, id, message)
end

# Check if the topic title contains certain keywords
# @param title [String] the title of the topic
# @return [Boolean] true if the title contains specific keywords, otherwise false
def check_title(title)
    if title.downcase.include?("codewizardshq.com") || title.downcase.include?("scratch.mit.edu")
        return true
    else
        return false
    end
end

# Check if the text includes valid link types
# @param text [String] the content of the post
# @return [Boolean] true if the text contains valid link types, otherwise false
def check_all_link_types(text)
    if (text.include?("codewizardshq.com") && !text.include?("/edit")) || (text.include?("cwhq-apps") || text.include?("scratch.mit.edu"))
        return true
    end
end

# Log a command with its details in a specified topic
# @param command [String] the command issued
# @param link [String] a relevant link to include in the log
# @param name [String] the username of the person who issued the command
def log_command(command, link, name)
    log_topic_id = 11303
    text = "@#{name} #{command}:<br>#{link}"
    create_post(log_topic_id, text)
end

# Send a private message to a user
# @param title [String] the title of the private message
# @param text [String] the content of the private message
# @param user [String] the username of the recipient
def send_pm(title, text, user)
    message = PostCreator.create!(
        Discourse.system_user,
        title: title,
        raw: text,
        archetype: Archetype.private_message,
        target_usernames: user,
        skip_validations: true
    )
end

# Notify the author of a closed topic via private message
# @param author_username [String] the username of the author
# @param topic_id [Integer] the ID of the closed topic
# @param message [String] the reason for closing the topic
def send_pm_to_author(author_username, topic_id, message)
    title = "Your topic (ID: #{topic_id}) has been closed"
    text = "Hello @#{author_username},\n\nYour topic (ID: #{topic_id}) has been closed. Reason: #{message}\n\nIf you have any questions or need further assistance, feel free to reach out to us.\n\nBest regards,\nThe CodeWizardsHQ Team"
    send_pm(title, text, author_username)
end

# Event handler for when a topic is created
after_initialize do
    DiscourseEvent.on(:topic_created) do |topic|
        newTopic = Post.find_by(topic_id: topic.id, post_number: 1)
        topicRaw = newTopic.raw
        lookFor = topic.user.username + ".codewizardshq.com"
        link = false
        if link then
            if topicRaw.downcase.include?(lookFor + "/edit") then
                text = "Hello @#{topic.user.username}, it appears that the link you provided goes to the editor, and not your project. Please open your project and use the link from that tab. This may look like " + link + "."
                create_post(topic.id, text)
                log_command("received an editor link message", "https://forum.codewizardshq.com/t/#{topic.topic_id}", topic.user.username)
            elsif !topicRaw.downcase.include?(lookFor) && !topicRaw.downcase.include?("cwhq-apps.com") then
                text = "Hello @#{topic.user.username}, it appears that you did not provide a link to your project. In order to receive the best help, please edit your topic to contain a link to your project. This may look like " + link + "."
                create_post(topic.id, text)
                log_command("received a missing link message", "https://forum.codewizardshq.com/t/#{topic.topic_id}", topic.user.username)
            end
        end

        topic_title = topic.title
        
        if check_title(topic_title) then
            text = "Hello @#{topic.user.username}, it appears you provided a link in your topic's title. Please change the title of this topic to something that clearly explains what the topic is about. This will help other forum users know what you want to show or get help with. You can edit your topic title by pressing the pencil icon next to the current one. Be sure to put the link in the main body of your post."
            if topicRaw.downcase.include?(lookFor) || topicRaw.downcase.include?("scratch.mit.edu") then
                create_post(topic.id, text)
                log_command("received a link in topic title message", "https://forum.codewizardshq.com/t/#{topic.topic_id}", topic.user.username)
            else
                create_post(topic.id, text)
                log_command("received a link in topic title message", "https://forum.codewizardshq.com/t/#{topic.topic_id}", topic.user.username)
            end
        end
    end

    # Event handler for when a post is created
    DiscourseEvent.on(:post_created) do |post|
        if post.post_number != 1 && post.user_id != -1 && post.raw.downcase.include?("codewizardshq.com") then
            text = "Hello @#{post.user.username}, it appears that you included a link in your post that is potentially an editor link. Please provide the final project link instead. This will help other users access and assist with your project effectively."
            create_post(post.topic_id, text)
        end
    end
end
