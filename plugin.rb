# name: CWHQ-Discourse-Bot
# about: This plugin adds extra functionality to the @system user on a Discourse forum.
# version: 1.9.0
# authors: Qursch, bronze0202, linuxmasters, sep208, Astr0clad, usrbinsam, daniel-schroeder-dev, sharpkeen, shriyash-shukla
# url: https://github.com/codewizardshq/CWHQ-Discourse-Bot

require 'date'

# Hash of course IDs and corresponding URLs or project identifiers
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

# Retrieves the link for a given course ID and username
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

# Creates a post in a specific topic
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

# Closes a topic and sends a private message to the topic's author
def closeTopic(id, message)
    topic = Topic.find_by(id: id)
    topic.update_status("closed", true, Discourse.system_user, { message: message })
    author_username = topic.user.username
    send_pm_to_author(author_username, id, message)
end

# Checks if the topic title includes specific links
def check_title(title)
    if title.downcase.include?("codewizardshq.com") || title.downcase.include?("scratch.mit.edu")
        return true
    else
        return false
    end
end

# Checks if the text contains specific types of links
def check_all_link_types(text)
    if (text.include?("codewizardshq.com") && !text.include?("/edit")) || (text.include?("cwhq-apps") || text.include?("scratch.mit.edu"))
        return true
    end
end

# Logs a command executed by a user to a specific log topic
def log_command(command, link, name)
    log_topic_id = 11303
    text = "@#{name} #{command}:<br>#{link}"
    create_post(log_topic_id, text)
end

# Sends a private message to a user
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

# Sends a private message to the author informing them that their topic has been closed
def send_pm_to_author(author_username, topic_id, message)
    title = "Your topic (ID: #{topic_id}) has been closed"
    text = "Hello @#{author_username},\n\nYour topic (ID: #{topic_id}) has been closed. Reason: #{message}\n\nIf you have any questions or need further assistance, feel free to reach out to us.\n\nBest regards,\nThe CodeWizardsHQ Team"
    send_pm(title, text, author_username)
end

after_initialize do
    DiscourseEvent.on(:topic_created) do |topic| 
        newTopic = Post.find_by(topic_id: topic.id, post_number: 1)
        topicRaw = newTopic.raw
        lookFor = topic.user.username + ".codewizardshq.com"
        # Determine the appropriate link for the topic
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
                log_command("received a link in topic title message",  "https://forum.codewizardshq.com/t/#{topic.topic_id}", topic.user.username)
            end
        end
    end

    DiscourseEvent.on(:post_created) do |post|
        if post.post_number != 1 && post.user_id != -1 then
            raw = post.raw
            oPost = Post.find_by(topic_id: post.topic_id, post_number: 1)
            group = Group.find_by(id: post.user.primary_group_id)
            helpLinks = "
            [Forum Videos](https://forum.codewizardshq.com/t/informational-videos/8662)
            [Rules Of The Forum](https://forum.codewizardshq.com/t/rules-of-the-codewizardshq-community-forum/43)
            [Create Good Questions And Answers](https://forum.codewizardshq.com/t/create-good-questions-and-answers/69)
            [Forum Guide](https://forum.codewizardshq.com/t/forum-new-user-guide/47)
            [Meet Forum Helpers](https://forum.codewizardshq.com/t/meet-the-forum-helpers/5474)
            [System Documentation](https://forum.codewizardshq.com/t/system-add-on-plugin-documentation/8742)
            [Understanding Trust Levels](https://blog.discourse.org/2018/06/understanding-discourse-trust-levels/)
            [Forum Information Category](https://forum.codewizardshq.com/c/official/information/69)"
            
            if raw[0, 7].downcase == "@system" then
                if raw.downcase.include?("topic closing") then
                    link = get_link(post.topic_id, post.user.username, courses)
                    if link then
                        text = "The following topic you created or replied to has been closed and linked to a project: " + link
                        create_post(post.topic_id, text)
                        log_command("topic closed message", "https://forum.codewizardshq.com/t/#{post.topic_id}", post.user.username)
                    end
                end
            end

            if check_all_link_types(raw) then
                text = "Hello @#{post.user.username}, we noticed that your post contains one or more links. Please check that your post includes the correct link and that it is relevant to your question or discussion. If your post contains incorrect or irrelevant links, it may be flagged. For more information, see the [Forum Rules](https://forum.codewizardshq.com/t/rules-of-the-codewizardshq-community-forum/43)."
                create_post(post.topic_id, text)
                log_command("posted a link message", "https://forum.codewizardshq.com/t/#{post.topic_id}", post.user.username)
            end
        end
    end

    # Event listener for topic updates
    DiscourseEvent.on(:topic_updated) do |topic|
        if topic.id == 32 then
            closeTopic(topic.id, "This topic is no longer relevant.")
        end
    end
end
