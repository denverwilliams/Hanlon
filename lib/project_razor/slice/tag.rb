
# Root ProjectRazor namespace
module ProjectRazor
  module Slice

    # ProjectRazor Slice Tag
    # Used for managing the tagging system
    class Tag < ProjectRazor::Slice::Base
      # Initializes ProjectRazor::Slice::Tag
      # @param [Array] args
      def initialize(args)
        super(args)
        @hidden = false
        @new_slice_style = true
        @slice_name = "Tag"
        # get the slice commands map for this slice (based on the set
        # of commands that are typical for most slices)
        @slice_commands = get_command_map("tag_help",
                                          "get_all_tagrules",
                                          "get_tagrule_by_uuid",
                                          "add_tagrule",
                                          "update_tagrule",
                                          "remove_all_tagrules",
                                          "remove_tagrule_by_uuid")
        # and add the corresponding 'matcher' commands to the set of slice_commands
        @slice_commands[:matcher] = get_command_map("tag_help",
                                                    nil,
                                                    "get_matcher_by_uuid",
                                                    "add_matcher",
                                                    "update_matcher",
                                                    nil,
                                                    "remove_matcher")
      end

      def tag_help
        puts get_tag_help
      end

      def get_tag_help
        return [ "Tag Slice:".red,
                 "Used to view, create, update, and remove Tag Rules and Tag Matchers.".red,
                 "Tag commands:".yellow,
                 "\trazor tag [get] [all]                           " + "View all Tag Rules/Matchers".yellow,
                 "\trazor tag [matcher] [get] (UUID)                " + "View a specific Tag Rule/Matcher".yellow,
                 "\trazor tag [matcher] add (options...)            " + "Create a new Tag Rule/Matcher".yellow,
                 "\trazor tag [matcher] update (UUID) (options...)  " + "Update an existing Tag Rule/Matcher".yellow,
                 "\trazor tag [matcher] remove (UUID)               " + "Remove an existing Tag Rule/Matcher".yellow,
                 "\trazor tag remove all                            " + "Remove all existing Tag Rules".yellow,
                 "\trazor tag --help|-h                             " + "Display this screen".yellow].join("\n")
      end

      def get_all_tagrules
        @command = :get_all_tagrules
        # Get all tag rules and print/return
        print_object_array(get_object("tagrules", :tag), "Tag Rules",
                           :style => :table, :success_type => :generic)
      end

      def get_tagrule_by_uuid
        @command = :get_tagrule_by_uuid
        # the UUID was the last "previous argument"
        tagrule_uuid = get_uuid_from_prev_args
        tagrule = get_object("tagrule_by_uuid", :tag, tagrule_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Tag Rule with UUID: [#{tagrule_uuid}]" unless tagrule
        print_object_array [tagrule], "", :success_type => :generic
      end

      def add_tagrule
        @command = :add_tagrule
        includes_uuid = false
        # load the appropriate option items for the subcommand we are handling
        option_items = load_option_items(:command => :add)
        # parse and validate the options that were passed in as part of this
        # subcommand (this method will return a UUID value, if present, and the
        # options map constructed from the @commmand_array)
        tmp, options = parse_and_validate_options(option_items, "razor tag add (options...)", :require_all)
        includes_uuid = true if tmp && tmp != "add"
        # check for usage errors (the boolean value at the end of this method
        # call is used to indicate whether the choice of options from the
        # option_items hash must be an exclusive choice)
        check_option_usage(option_items, options, includes_uuid, false)

        # create a new tagrule using the options that were passed into this subcommand,
        # then persist the tagrule object
        tagrule = ProjectRazor::Tagging::TagRule.new({"@name" => options[:name], "@tag" => options[:tag]})
        raise(ProjectRazor::Error::Slice::CouldNotCreate, "Could not create Tag Rule") unless tagrule
        setup_data
        @data.persist_object(tagrule)
        print_object_array([tagrule], "", :success_type => :created)
      end

      def update_tagrule
        @command = :update_tagrule
        includes_uuid = false
        # load the appropriate option items for the subcommand we are handling
        option_items = load_option_items(:command => :update)
        # parse and validate the options that were passed in as part of this
        # subcommand (this method will return the options map constructed
        # from the @commmand_array)
        tagrule_uuid, options = parse_and_validate_options(option_items, "razor tag update (UUID) (options...)", :require_one)
        includes_uuid = true if tagrule_uuid
        # check for usage errors (the boolean value at the end of this method
        # call is used to indicate whether the choice of options from the
        # option_items hash must be an exclusive choice)
        check_option_usage(option_items, options, includes_uuid, false)

        # get the tagfule to update
        tagrule = get_object("tagrule_with_uuid", :tag, tagrule_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Tag Rule with UUID: [#{tagrule_uuid}]" unless tagrule
        tagrule.name = options[:name] if options[:name]
        tagrule.tag = options[:tag] if options[:tag]
        raise ProjectRazor::Error::Slice::CouldNotUpdate, "Could not update Tag Rule [#{tagrule.uuid}]" unless tagrule.update_self
        print_object_array [tagrule], "", :success_type => :updated
      end

      def remove_all_tagrules
        @command = :remove_all_tagrules
        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove all Tag Rules" unless @data.delete_all_objects(:tag)
        slice_success("All Tag Rules removed", :success_type => :removed)
      end

      def remove_tagrule_by_uuid
        @command = :remove_tagrule_by_uuid
        # the UUID was the last "previous argument"
        tagrule_uuid = get_uuid_from_prev_args
        tagrule = get_object("tagrule_with_uuid", :tag, tagrule_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Tag Rule with UUID: [#{tagrule_uuid}]" unless tagrule
        setup_data
        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove Tag Rule [#{tagrule.uuid}]" unless @data.delete_object(tagrule)
        slice_success("Tag Rule [#{tagrule.uuid}] removed", :success_type => :removed)
      end

      # Tag Matcher
      #

      def find_matcher(matcher_uuid)
        found_matcher = []
        setup_data
        @data.fetch_all_objects(:tag).each do
        |tr|
          tr.tag_matchers.each do
          |matcher|
            found_matcher << [matcher, tr] if matcher.uuid.scan(matcher_uuid).count > 0
          end
        end
        found_matcher.count == 1 ? found_matcher.first : nil
      end

      def get_matcher_by_uuid
        @command = :get_matcher_by_uuid
        # the UUID was the last "previous argument"
        matcher_uuid = get_uuid_from_prev_args
        raise ProjectRazor::Error::Slice::MissingArgument, "Must provide a Tag Matcher UUID" unless validate_arg(matcher_uuid)
        matcher, tagrule = find_matcher(matcher_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot find Tag Matcher with UUID [#{matcher_uuid}]" unless matcher
        print_object_array [matcher], "", :success_type => :generic
      end

      def add_matcher
        @command = :add_matcher
        includes_uuid = false
        # load the appropriate option items for the subcommand we are handling
        option_items = load_option_items(:command => :add_matcher)
        # parse and validate the options that were passed in as part of this
        # subcommand (this method will return a UUID value, if present, and the
        # options map constructed from the @commmand_array)
        tmp, options = parse_and_validate_options(option_items, "razor tag matcher add (options...)", :require_all)
        includes_uuid if tmp && tmp != "add"
        # check for usage errors (the boolean value at the end of this method
        # call is used to indicate whether the choice of options from the
        # option_items hash must be an exclusive choice)
        check_option_usage(option_items, options, includes_uuid, false)
        tagrule_uuid = options[:tag_rule_uuid]
        key = options[:key]
        compare = options[:compare]
        value = options[:value]
        inverse = (options[:invert] == nil ? "false" : options[:invert])

        # check the values that were passed in
        tagrule = get_object("tagrule_with_uuid", :tag, tagrule_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Tag Rule with UUID: [#{tagrule_uuid}]" unless tagrule
        raise ProjectRazor::Error::Slice::MissingArgument, "Option for --compare must be [equal|like]" unless compare == "equal" || compare == "like"
        matcher = tagrule.add_tag_matcher(:key => key, :compare => compare, :value => value, :inverse => inverse)
        raise ProjectRazor::Error::Slice::CouldNotCreate, "Could not create tag matcher" unless matcher
        raise(ProjectRazor::Error::Slice::CouldNotCreate, "Could not create Tag Matcher") unless tagrule.update_self
        print_object_array([matcher], "Tag Matcher created:", :success_type => :created)
      end

      def update_matcher
        @command = :update_matcher
        includes_uuid = false
        # load the appropriate option items for the subcommand we are handling
        option_items = load_option_items(:command => :update_matcher)
        # parse and validate the options that were passed in as part of this
        # subcommand (this method will return a UUID value, if present, and the
        # options map constructed from the @commmand_array)
        matcher_uuid, options = parse_and_validate_options(option_items, "razor policy update UUID (options...)", :require_one)
        includes_uuid = true if matcher_uuid
        # check for usage errors (the boolean value at the end of this method
        # call is used to indicate whether the choice of options from the
        # option_items hash must be an exclusive choice)
        check_option_usage(option_items, options, includes_uuid, false)
        tagrule_uuid = options[:tag_rule_uuid]
        key = options[:key]
        compare = options[:compare]
        value = options[:value]
        invert = options[:invert]

        # check the values that were passed in
        matcher, tagrule = find_matcher(matcher_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot find Tag Matcher with UUID [#{matcher_uuid}]" unless matcher
        raise ProjectRazor::Error::Slice::MissingArgument, "Option for --compare must be [equal|like]" unless !compare || compare == "equal" || compare == "like"
        raise ProjectRazor::Error::Slice::MissingArgument, "Option for --invert must be [true|false]" unless !invert || invert == "true" || invert == "false"
        matcher.key = key if key
        matcher.compare = compare if compare
        matcher.value = value if value
        matcher.inverse = invert if invert
        if tagrule.update_self
          print_object_array([matcher], "Tag Matcher updated [#{matcher.uuid}]\nTag Rule:", :success_type => :updated)
        else
          raise(ProjectRazor::Error::Slice::CouldNotCreate, "Could not update Tag Matcher")
        end
      end

      def remove_matcher
        @command = :remove_matcher
        # the UUID was the last "previous argument"
        matcher_uuid = get_uuid_from_prev_args
        matcher, tagrule = find_matcher(matcher_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot find Tag Matcher with UUID [#{matcher_uuid}]" unless matcher
        raise ProjectRazor::Error::Slice::CouldNotCreate, "Could not remove Tag Matcher" unless tagrule.remove_tag_matcher(matcher.uuid)
        raise(ProjectRazor::Error::Slice::CouldNotCreate, "Could not remove Tag Matcher") unless tagrule.update_self
        print_object_array([tagrule], "Tag Matcher removed [#{matcher.uuid}]\nTag Rule:", :success_type => :removed)
      end

    end
  end
end

