# encoding: utf-8

# Python helper for headlights.vim
# Version: 1.5.2

# context vars (global)
hl_bundles = {}
hl_menus = []
hl_errors = []
hl_start_time = 0

# data vars (global)
hl_vim_execution_time = 0
hl_scriptnames = ""
hl_categories = []

def run_headlights(vim_time, vim_scriptnames, **vim_categories):
    """Initialise the default settings and control the execution."""

    global hl_start_time, hl_vim_execution_time, hl_scriptnames, hl_categories, HL_ERROR_MSG

    hl_start_time = time.time()
    hl_vim_execution_time = vim_time
    hl_scriptnames = vim_scriptnames
    hl_categories = vim_categories

    try:
        attach_menus()

    # log unexpected errors to file
    except:
        import traceback
        hl_errors.insert(0, traceback.format_exc())
        # generate the debug log
        log_name = do_debug()
        sys.stdout.write("%s" % traceback.format_exc())
        sys.stdout.write("Headlights error. See the debug log for details: %s" % log_name)

def attach_menus():
    """Coordinate the action and attach the vim menus (minimising vim sphagetti)."""

    global HL_ERROR_MSG

    root = HL_MENU_ROOT
    new_line = os.linesep

    parse_scriptnames()

    # parse the menu categories with the similarly named functions
    for key in iter(list(hl_categories.keys())):
        if hl_categories[key]:
            function = globals()["parse_" + key]
            function(hl_categories[key].strip().split("\n"))

    # generate the menu commands
    for path, properties in iter(list(hl_bundles.items())):
        name = properties["name"]

        spillover = sanitise_menu(get_spillover(name, path))

        name = sanitise_menu(name)

        prefix = "%(root)s.%(spillover)s.%(name)s." % locals()
        prefix = "%(root)s.%(spillover)s.%(name)s." % locals()

        gen_menus(name, prefix, path, properties)

        # duplicate local buffer menus for convenience
        if hl_bundles[path]["buffer"]:
            prefix = "%(root)s.⁣⁣buffer.%(name)s." % locals()
            gen_menus(name, prefix, path, properties)

    hl_menus.sort(key=lambda menu: menu.lower())

    if HL_DEBUG_MODE:
        # do the debug log and menus
        do_debug()

        # attach the vim menus, skipping any bad vim menu commands
        for menu_command in hl_menus:
            try:
                vim.command("%(menu_command)s" % locals())
            except vim.error:
                menu_error = "Couldn't run Vim menu command: '%(menu_command)s'" % locals()
                hl_errors.insert(0, menu_error)
                # redo the debug log and menus
                log_name = do_debug()
                sys.stdout.write("%(menu_error)s%(new_line)s" % locals())
                sys.stdout.write(HL_MENU_ERROR)
                continue

    # just attach the vim menus (faster)
    else:
        try:
            [vim.command("%(menu_command)s" % locals()) for menu_command in hl_menus]
        except vim.error:
            sys.stdout.write(HL_MENU_ERROR)

def parse_scriptnames():
    """Extract the bundles (aka scriptnames/plugins)."""

    global hl_scriptnames

    hl_scriptnames = hl_scriptnames.strip().split("\n")

    for line in hl_scriptnames:
        # strip leading indexes
        matches = HL_SCRIPTNAME_PATTERN.match(line)

        order = matches.group("order")
        path = matches.group("path")

        init_bundle(expand_home(path), order)

def init_bundle(path, order):
    """Initialise new bundles (aka scripts/plugins)."""

    # use the filename as the default bundle name
    name = os.path.splitext(os.path.basename(path))[0]

    # use the file dir as the default bundle root
    root = os.path.dirname(path)

    if HL_SMART_MENUS:
        # find the actual bundle root (ignoring runtime bundles). break out of standard vim dirs, if necessary.
        if "/runtime/" not in root.lower():
            for pattern in HL_VIM_DIR_PATTERNS:
                if re.match(pattern, root):
                    parent = re.sub("/\w+$", "", root)
                    # make sure we're not in a nested dir (eg. autoload, ftplugin, after)
                    while re.match(pattern, parent):
                        parent = re.sub("/\w+$", "", parent)

                    # ignore bundles in the vim dir
                    if parent != os.getenv("HOME"):
                        # set the parent path as the new root
                        root = parent
                        # set the name of the parent dir as the new name
                        name = os.path.splitext(os.path.basename(parent))[0]

                    break

        # now that we (probably) know the root, check previous bundles for a matching root
        # ignore vimrc files and bundles in the runtime dir
        if "/runtime/" not in path and not name.endswith("vimrc"):
            for key in iter(list(hl_bundles.keys())):
                if root == hl_bundles[key]["root"]:
                    # if we have a match, group the bundles together by the previous name
                    name = hl_bundles[key]["name"]
                    break

    # remove the 'vim-' prefix from bundle names (a source control project thing)
    if name.startswith("vim-"):
        name = name[4:]

    # remove the '_vim' suffix from bundle names (a source control project thing)
    if name.endswith("_vim"):
        name = name[:-4]

    hl_bundles[path] = {
        "order": order,
        "name": name,
        "root": root,
        "commands": [],
        "mappings": [],
        "abbreviations": [],
        "functions": [],
        "highlights": [],
        "buffer": False
    }

    return hl_bundles[path]

def parse_commands(commands):
    """Extract the commands."""

    # delete the listing header
    commands = commands[1:]

    for i, line in enumerate(commands):
        # begin with command lines
        if HL_SOURCE_LINE not in line:
            matches = HL_COMMAND_PATTERN.match(line)

            try:
                command = matches.group("name")
            except AttributeError:
                hl_errors.append("parse_commands: no command name found in command '%(line)s'" % locals())
                continue

            definition = matches.group("definition")

            # a vim command can be declared with no definition (just a :)
            try:
                definition = definition.strip()
            except AttributeError:
                definition = ""

            # get the source script from the next list item
            try:
                source_script = get_source_script(commands[i + 1])

                if matches.group("buffer"):
                    source_script["buffer"] = True

                source_script["commands"].append([command, definition])

            except IndexError:
                hl_errors.append("parse_command: source line not found for command '%(line)s'" % locals())
                continue
            except TypeError:
                hl_errors.append("parse_command: source script not initialised for command '%(line)s'" % locals())
                continue

def parse_modes(mode):
    """Return a list of all the modes."""

    # restore empty mode to original value (space)
    if not mode:
        mode = " "

    # cater for multiple modes
    modes = list(mode)

    # translate to mode descriptions
    modes = [HL_MODE_MAP.get(mode) for mode in modes]

    return modes

def parse_mappings(mappings):
    """Extract the mappings."""

    for i, line in enumerate(mappings):
        # begin with mapping lines
        if HL_SOURCE_LINE not in line:
            matches = HL_MAPPING_PATTERN.match(line)

            try:
                lhs = matches.group("lhs")
            except AttributeError:
                hl_errors.append("parse_mappings: lhs not found for mapping '%(line)s'" % locals())
                continue

            try:
                rhs = matches.group("rhs").strip()
            except AttributeError:
                hl_errors.append("parse_mappings: rhs not found for mapping '%(line)s'" % locals())
                continue

            modes = parse_modes(matches.group("modes"))

            # get the source script from the next list item
            try:
                source_script = get_source_script(mappings[i + 1])

                # flag the bundle as buffer local, and prepend an indicator to the mapping
                if matches.group("buffer"):
                    source_script["buffer"] = True

                # add the mapping to the source script
                for mode in modes:
                    source_script["mappings"].append([mode, lhs, rhs])

            except IndexError:
                hl_errors.append("parse_mappings: source line not found for mapping '%(line)s'" % locals())
                continue
            except TypeError:
                hl_errors.append("parse_mappings: source script not initialised for mapping '%(line)s'" % locals())
                continue

def parse_abbreviations(abbreviations):
    """Extract the abbreviations."""

    for i, line in enumerate(abbreviations):
        # begin with abbreviation lines
        if HL_SOURCE_LINE not in line:
            matches = HL_ABBREV_PATTERN.match(line)

            try:
                lhs = matches.group("lhs")
            except AttributeError:
                hl_errors.append("parse_abbreviations: lhs not found for abbreviation '%(line)s'" % locals())
                continue

            try:
                rhs = matches.group("rhs").strip()
            except AttributeError:
                hl_errors.append("parse_abbreviations: rhs not found for abbreviation '%(line)s'" % locals())
                continue

            modes = parse_modes(matches.group("modes"))

            # get the source script from the next list item
            try:
                source_script = get_source_script(abbreviations[i + 1])

                # flag the bundle as buffer local, and prepend an indicator to the mapping
                if matches.group("buffer"):
                    source_script["buffer"] = True

                # add the abbreviation to the source script
                for mode in modes:
                    source_script["abbreviations"].append([mode, lhs, rhs])

            except IndexError:
                hl_errors.append("parse_abbreviations: source line not found for abbreviation '%(line)s'" % locals())
                continue
            except TypeError:
                hl_errors.append("parse_mappings: source script not initialised for abbreviation '%(line)s'" % locals())
                continue

def parse_functions(functions):
    """Extract the functions."""

    for i, line in enumerate(functions):
        # begin with function lines
        if HL_SOURCE_LINE not in line:
            function = line.split("function ")[1]

            # get the source script from the next list item
            source_script = get_source_script(functions[i + 1])

            # add the function to the source script (global/public functions only)
            if not function.startswith("<SNR>") and "#" not in function:
                source_script["functions"].append(function)

def parse_highlights(highlights):
    """Extract the highlights."""

    for i, line in enumerate(highlights):
        # begin with highlight lines
        if HL_SOURCE_LINE not in line:
            matches = HL_HIGHLIGHT_PATTERN.match(line)

            try:
                group = matches.group("group")
            except AttributeError:
                # not a typical highlight command, ignore
                continue

            arguments = matches.group("arguments")

            if not arguments.startswith("cleared") and not arguments.startswith("links to "):
                # get the source script from the next list item
                source_script = get_source_script(highlights[i + 1])

                terminal_list = {}

                for argument in arguments.split(" "):
                    terminal, attributes = argument.split("=")

                    attribute_list = attributes.split(",")

                    terminal_list[terminal] = attribute_list

                # add the highlights to the source script
                try:
                    source_script["highlights"].append([group, terminal_list])
                except TypeError:
                    continue

def get_source_script(line):
    """Extract the source script from the line and return the bundle."""

    script_path = line.replace(HL_SOURCE_LINE, "").strip()

    return hl_bundles.get(expand_home(script_path))

def expand_home(path):
    """Return the absolute home path for forward compatibility with later vim versions."""
    return os.getenv("HOME") + path[1:] if path.startswith("~") else path

def sanitise_menu(menu):
    """Escape special characters in vim menus."""
    return menu.replace("\\", "\\\\").replace("|", "\\|").replace(".", "\\.").replace(" ", "\\ ").replace("<", "\\<")

def get_spillover(name, path):
    """Return an appropriate menu category/spillover parent."""

    # a catch all, just in case
    spillover = "⁣other"

    name = name.strip()

    # use empty chars (looks like space) to move menus to the bottom
    # and exclude vimrc files from buffer local menus (for simplicity)
    if hl_bundles[path]["name"].endswith("vimrc"):
        spillover = "⁣vimrc"
    elif "/runtime/" in path.lower():
        spillover = "⁣runtime"
    else:
        for pattern, category in list(HL_MENU_SPILLOVER_PATTERNS.items()):
            if pattern.match(name):
                spillover = category
                break

    return spillover

def gen_menus(name, prefix, path, properties):
    """Generate menus for enabled categories."""

    # this needs to be first so sort() can get the script order right
    gen_help_menu(name, prefix)

    if HL_SHOW_FILES:
        gen_files_menu(path, prefix, properties["order"])

    if len(properties["commands"]) > 0:
        gen_commands_menu(properties["commands"], prefix)

    if len(properties["mappings"]) > 0:
        gen_mappings_menu(properties["mappings"], prefix)

    if len(properties["abbreviations"]) > 0:
        gen_abbreviations_menu(properties["abbreviations"], prefix)

    if len(properties["functions"]) > 0:
        gen_functions_menu(properties["functions"], prefix)

    if len(properties["highlights"]) > 0:
        gen_highlights_menu(properties["highlights"], prefix)

def gen_help_menu(name, prefix):
    """Add help menus."""

    help_priority = "9997.100"
    sep_priority = "9997.110"

    help_item = "amenu <silent> %(help_priority)s %(prefix)sHelp :help %(name)s<CR>" % locals()
    hl_menus.append(help_item)

    sep_item = "amenu <silent> %(sep_priority)s %(prefix)s-Sep1- :" % locals()
    hl_menus.append(sep_item)

def gen_files_menu(path, prefix, load_order):
    """Add file menus."""

    item_priority = "9997.160"

    file_path = trunc_file_path = sanitise_menu(path)
    file_dir_path = sanitise_menu(os.path.dirname(path))

    # unescape dots so path commands can be run
    file_path_cmd = file_path.replace("\\.", ".")
    file_dir_path_cmd = file_dir_path.replace("\\.", ".")

    if len(file_path) > HL_MENU_TRUNC_LIMIT:
        trunc_file_path = "<" + sanitise_menu(path[-HL_MENU_TRUNC_LIMIT:])

    if sys.platform == "darwin":
        reveal_cmd = "silent !open"

    open_item = "amenu <silent> %(item_priority)s.10 %(prefix)sFiles.%(trunc_file_path)s.Open\ File<Tab>%(file_path)s :tabnew %(file_path_cmd)s<CR>" % locals()
    hl_menus.append(open_item)

    explore_item = "amenu <silent> %(item_priority)s.20 %(prefix)sFiles.%(trunc_file_path)s.Explore\ in\ Vim<Tab>%(file_dir_path)s :Texplore %(file_dir_path_cmd)s<CR>" % locals()
    hl_menus.append(explore_item)

    try:
        reveal_item = "amenu <silent> %(item_priority)s.30 %(prefix)sFiles.%(trunc_file_path)s.Explore\ in\ System<Tab>%(file_dir_path)s :%(reveal_cmd)s %(file_dir_path_cmd)s<CR>" % locals()
        hl_menus.append(reveal_item)
    except KeyError:
        pass    # no reveal item for this platform

    if HL_SHOW_LOAD_ORDER:
        sep_item = "amenu <silent> %(item_priority)s.40 %(prefix)sFiles.%(trunc_file_path)s.-Sep1- :" % locals()
        hl_menus.append(sep_item)

        order_item = "amenu <silent> %(item_priority)s.50 %(prefix)sFiles.%(trunc_file_path)s.Order:\ %(load_order)s :" % locals()
        hl_menus.append(order_item)
        disabled_item = "amenu <silent> disable %(prefix)sFiles.%(trunc_file_path)s.Order:\ %(load_order)s" % locals()
        hl_menus.append(disabled_item)

def gen_commands_menu(commands, prefix):
    """Add command menus."""

    item_priority = "9997.120"

    for command in commands:
        name = sanitise_menu(command[0])
        definition = sanitise_menu(command[1])

        command_item = "amenu <silent> %(item_priority)s %(prefix)sCommands.%(name)s :%(name)s<CR>" % locals()
        hl_menus.append(command_item)

def gen_mappings_menu(mappings, prefix):
    """Add mapping menus."""

    item_priority = "9997.130"

    for mode, lhs, rhs in mappings:
        mode = sanitise_menu(mode)
        lhs = sanitise_menu(lhs)
        rhs = sanitise_menu(rhs)

        mapping_item = "amenu <silent> %(item_priority)s %(prefix)sMappings.%(mode)s.%(lhs)s<Tab>%(rhs)s :" % locals()
        hl_menus.append(mapping_item)
        disabled_item = "amenu <silent> disable %(prefix)sMappings.%(mode)s.%(lhs)s" % locals()
        hl_menus.append(disabled_item)

def gen_abbreviations_menu(abbreviations, prefix):
    """Add abbreviation menus."""

    item_priority = "9997.140"

    for mode, lhs, rhs in abbreviations:
        mode = sanitise_menu(mode)
        lhs = trunc_lhs = sanitise_menu(lhs)
        rhs = sanitise_menu(rhs)

        if len(lhs) > HL_MENU_TRUNC_LIMIT:
            trunc_lhs = lhs[:HL_MENU_TRUNC_LIMIT] + ">"

        # prefix mode with an invisible char so vim can create mode menus separate from mappings'
        abbr_item = "amenu <silent> %(item_priority)s %(prefix)s⁣Abbreviations.%(mode)s.%(trunc_lhs)s<Tab>%(rhs)s :" % locals()
        hl_menus.append(abbr_item)
        disabled_item = "amenu <silent> disable %(prefix)s⁣Abbreviations.%(mode)s.%(trunc_lhs)s" % locals()
        hl_menus.append(disabled_item)

def gen_functions_menu(functions, prefix):
    """Add function menus."""

    item_priority = "9997.150"

    for function in functions:
        trunc_function = sanitise_menu(function)
        function_label = ""

        # only show a label if the function name is truncated
        if len(function) > HL_MENU_TRUNC_LIMIT:
            function_label = trunc_function
            trunc_function = trunc_function[:HL_MENU_TRUNC_LIMIT] + ">"

        function_item = "amenu <silent> %(item_priority)s %(prefix)sFunctions.%(trunc_function)s<Tab>%(function_label)s :" % locals()
        hl_menus.append(function_item)
        disabled_item = "amenu <silent> disable %(prefix)sFunctions.%(trunc_function)s" % locals()
        hl_menus.append(disabled_item)

def gen_highlights_menu(highlights, prefix):
    """Add highlight menus."""

    item_priority = "9997.150"

    for group, terminal_list in highlights:
        group = sanitise_menu(group)

        for terminal, attribute_list in iter(list(terminal_list.items())):
            terminal = sanitise_menu(terminal)

            for attribute in attribute_list:
                attribute = sanitise_menu(attribute)
                highlight_item = "amenu <silent> %(item_priority)s %(prefix)sHighlights.%(group)s.%(terminal)s.%(attribute)s<Tab>Copy\ to\ clipboard :let @* = '%(attribute)s'<CR>" % locals()
                hl_menus.append(highlight_item)

def gen_debug_menu(log_name):
    """Add debug menus."""

    sep_priority = "9997.300"
    open_priority = "9997.310"
    texplore_priority = "9997.320"
    explore_priority = "9997.330"

    log_name_label = sanitise_menu(log_name)
    log_dir = os.path.dirname(log_name)

    root = HL_MENU_ROOT

    sep_item = "amenu <silent> %(sep_priority)s %(root)s.-SepHLD- :" % locals()
    hl_menus.append(sep_item)

    if sys.platform == "darwin":
        reveal_log_cmd = "!open"

    open_item = "amenu <silent> %(open_priority)s %(root)s.debug.Open\ Log<Tab>%(log_name_label)s :tabnew %(log_name)s<CR>" % locals()
    hl_menus.append(open_item)

    explore_item = "amenu <silent> %(texplore_priority)s %(root)s.debug.Explore\ in\ Vim<Tab>%(log_dir)s :Texplore %(log_dir)s<CR>" % locals()
    hl_menus.append(explore_item)

    try:
        reveal_item = "amenu <silent> %(explore_priority)s %(root)s.debug.Explore\ in\ System<Tab>%(log_dir)s :%(reveal_log_cmd)s %(log_dir)s<CR>" % locals()
        hl_menus.append(reveal_item)
    except KeyError:
        pass    # no reveal item for this platform

def do_debug():
    """Attach the debug menu and write the log file."""

    import tempfile
    import platform

    log_file = tempfile.NamedTemporaryFile(prefix=HL_LOGNAME_PREFIX, suffix=HL_LOGNAME_SUFFIX, delete=False)

    gen_debug_menu(log_file.name)

    date = time.ctime()
    platform = platform.platform()
    errors = "\n".join(hl_errors)
    scriptnames = "\n".join(hl_scriptnames)
    categories = "\n\n".join("%s:%s" % (key.upper(), hl_categories[key]) for key in iter(list(hl_categories.keys())))
    menus = "\n".join(hl_menus)
    vim_time = hl_vim_execution_time
    python_time = time.time() - hl_start_time

    log_file.write("""Headlights -- Vim Debug Log

DATE: %(date)s
PLATFORM: %(platform)s

This is the debug log for Headlights <https://github.com/mbadran/headlights/>
For details on how to raise a GitHub issue, see :help headlights-issues
Don't forget to disable debug mode if you've specifically enabled it.

ERRORS:
%(errors)s

SCRIPTNAMES:
%(scriptnames)s

%(categories)s

MENUS:
%(menus)s

Headlights vim code executed in %(vim_time).2f seconds
Headlights python code executed in %(python_time).2f seconds

(Vim menu commands not timed.)
""" % locals())

    log_file.close()

    return log_file.name
