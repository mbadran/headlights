# encoding: utf-8

# Python helper for headlights.vim
# Version: 1.5

# global configuration vars
MENU_ROOT = sys.argv[0]
SHOW_FILES = sys.argv[1]
SHOW_LOAD_ORDER = sys.argv[2]
SMART_MENUS = sys.argv[3]
DEBUG_MODE = sys.argv[4]
MODE_MAP = sys.argv[5]
SOURCE_LINE = sys.argv[6]
MENU_TRUNC_LIMIT = sys.argv[7]
MENU_SPILLOVER_PATTERNS = sys.argv[8]
COMMAND_PATTERN = sys.argv[9]
MAPPING_PATTERN = sys.argv[10]
ABBREV_PATTERN = sys.argv[11]
HIGHLIGHT_PATTERN = sys.argv[12]
SCRIPTNAME_PATTERN = sys.argv[13]
VIM_DIR_PATTERNS = sys.argv[14]

# global context vars
bundles = {}
menus = []
errors = []
start_time = 0

# global data vars
vim_execution_time = 0
scriptnames = ""
categories = []

def run_headlights(vim_time, vim_scriptnames, **vim_categories):
    """Initialise the default settings and control the execution."""

    global start_time, vim_execution_time, scriptnames, categories

    start_time = time.time()
    vim_execution_time = vim_time
    scriptnames = vim_scriptnames
    categories = vim_categories

    # for quick profiling, reverse comments
    attach_menus()
    # import cProfile
    # DEBUG_MODE = False
    # cProfile.runctx("attach_menus()", globals(), locals())

def init_bundle(path, order):
    """Initialise new bundles (aka scripts/plugins)."""

    # use the filename as the default bundle name
    name = os.path.splitext(os.path.basename(path))[0]

    # use the file dir as the default bundle root
    root = os.path.dirname(path)

    if SMART_MENUS:
        # find the actual bundle root (ignoring runtime bundles). break out of standard vim dirs, if necessary.
        if not root.lower().find("/runtime/") > -1:
            for pattern in VIM_DIR_PATTERNS:
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
        if path.find("/runtime/") == -1 and not name.endswith("vimrc"):
            for key in iter(list(bundles.keys())):
                if root == bundles[key]["root"]:
                    # if we have a match, group the bundles together by the previous name
                    name = bundles[key]["name"]
                    break

    bundles[path] = {
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

    return bundles[path]

def get_spillover(name, path):
    """Return an appropriate menu category/spillover parent."""

    # a catch all, just in case
    spillover = "⁣other"

    name = name.strip()

    # use empty chars (looks like space) to move menus to the bottom
    # and exclude vimrc files from buffer local menus (for simplicity)
    if bundles[path]["name"].endswith("vimrc"):
        spillover = "⁣vimrc"
    elif path.lower().find("/runtime/") > -1:
        spillover = "⁣runtime"
    else:
        for pattern, category in list(MENU_SPILLOVER_PATTERNS.items()):
            if pattern.match(name):
                spillover = category
                break

    return spillover

def gen_menus(name, prefix, path, properties):
    """Generate menus for enabled categories."""

    # this needs to be first so sort() can get the script order right
    gen_help_menu(name, prefix)

    if SHOW_FILES:
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

def gen_commands_menu(commands, prefix):
    """Add command menus."""

    item_priority = "9997.120"

    for command in commands:
        name = sanitise_menu(command[0])
        definition = sanitise_menu(command[1])

        command_item = "amenu <silent> %(item_priority)s %(prefix)sCommands.%(name)s :%(name)s<CR>" % locals()
        menus.append(command_item)

def gen_files_menu(path, prefix, load_order):
    """Add file menus."""

    item_priority = "9997.160"

    file_path = trunc_file_path = sanitise_menu(path)
    file_dir_path = sanitise_menu(os.path.dirname(path))

    # unescape dots so path commands can be run
    file_path_cmd = file_path.replace("\\.", ".")
    file_dir_path_cmd = file_dir_path.replace("\\.", ".")

    if len(file_path) > MENU_TRUNC_LIMIT:
        trunc_file_path = "<" + sanitise_menu(path[-MENU_TRUNC_LIMIT:])

    if sys.platform == "darwin":
        # make the file appear in the "file > open recent" menu
        # also, honour the macvim option, "open files from applications"
        # (this doesn't take into account terminal vim, but menu access there is probably uncommon)
        open_cmd = "!open -a MacVim"
        reveal_cmd = "!open"
    else:
        open_cmd = "edit"

    open_item = "amenu <silent> %(item_priority)s.10 %(prefix)sFiles.%(trunc_file_path)s.Open\ File<Tab>%(file_path)s :%(open_cmd)s %(file_path_cmd)s<CR>" % locals()
    menus.append(open_item)

    explore_item = "amenu <silent> %(item_priority)s.20 %(prefix)sFiles.%(trunc_file_path)s.Explore\ in\ Vim<Tab>%(file_dir_path)s :Texplore %(file_dir_path_cmd)s<CR>" % locals()
    menus.append(explore_item)

    try:
        reveal_item = "amenu <silent> %(item_priority)s.30 %(prefix)sFiles.%(trunc_file_path)s.Explore\ in\ System<Tab>%(file_dir_path)s :%(reveal_cmd)s %(file_dir_path_cmd)s<CR>" % locals()
        menus.append(reveal_item)
    except KeyError:
        pass    # no reveal item for this platform

    if SHOW_LOAD_ORDER:
        sep_item = "amenu <silent> %(item_priority)s.40 %(prefix)sFiles.%(trunc_file_path)s.-Sep1- :" % locals()
        menus.append(sep_item)

        order_item = "amenu <silent> %(item_priority)s.50 %(prefix)sFiles.%(trunc_file_path)s.Order:\ %(load_order)s :" % locals()
        menus.append(order_item)
        disabled_item = "amenu <silent> disable %(prefix)sFiles.%(trunc_file_path)s.Order:\ %(load_order)s" % locals()
        menus.append(disabled_item)

def gen_mappings_menu(mappings, prefix):
    """Add mapping menus."""

    item_priority = "9997.130"

    for mode, lhs, rhs in mappings:
        mode = sanitise_menu(mode)
        lhs = sanitise_menu(lhs)
        rhs = sanitise_menu(rhs)

        mapping_item = "amenu <silent> %(item_priority)s %(prefix)sMappings.%(mode)s.%(lhs)s<Tab>%(rhs)s :" % locals()
        menus.append(mapping_item)
        disabled_item = "amenu <silent> disable %(prefix)sMappings.%(mode)s.%(lhs)s" % locals()
        menus.append(disabled_item)

def gen_abbreviations_menu(abbreviations, prefix):
    """Add abbreviation menus."""

    item_priority = "9997.140"

    for mode, lhs, rhs in abbreviations:
        mode = sanitise_menu(mode)
        lhs = trunc_lhs = sanitise_menu(lhs)
        rhs = sanitise_menu(rhs)

        if len(lhs) > MENU_TRUNC_LIMIT:
            trunc_lhs = lhs[:MENU_TRUNC_LIMIT] + ">"

        # prefix mode with an invisible char so vim can create mode menus separate from mappings'
        abbr_item = "amenu <silent> %(item_priority)s %(prefix)s⁣Abbreviations.%(mode)s.%(trunc_lhs)s<Tab>%(rhs)s :" % locals()
        menus.append(abbr_item)
        disabled_item = "amenu <silent> disable %(prefix)s⁣Abbreviations.%(mode)s.%(trunc_lhs)s" % locals()
        menus.append(disabled_item)

def gen_help_menu(name, prefix):
    """Add help menus."""

    help_priority = "9997.100"
    sep_priority = "9997.110"

    help_item = "amenu <silent> %(help_priority)s %(prefix)sHelp :help %(name)s<CR>" % locals()
    menus.append(help_item)

    sep_item = "amenu <silent> %(sep_priority)s %(prefix)s-Sep1- :" % locals()
    menus.append(sep_item)

def gen_functions_menu(functions, prefix):
    """Add function menus."""

    item_priority = "9997.150"

    for function in functions:
        trunc_function = sanitise_menu(function)
        function_label = ""

        # only show a label if the function name is truncated
        if len(function) > MENU_TRUNC_LIMIT:
            function_label = trunc_function
            trunc_function = trunc_function[:MENU_TRUNC_LIMIT] + ">"

        function_item = "amenu <silent> %(item_priority)s %(prefix)sFunctions.%(trunc_function)s<Tab>%(function_label)s :" % locals()
        menus.append(function_item)
        disabled_item = "amenu <silent> disable %(prefix)sFunctions.%(trunc_function)s" % locals()
        menus.append(disabled_item)

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
                menus.append(highlight_item)

def gen_debug_menu(log_name):
    """Add debug menus."""

    sep_priority = "9997.300"
    open_priority = "9997.310"
    texplore_priority = "9997.320"
    explore_priority = "9997.330"

    log_name_label = sanitise_menu(log_name)
    log_dir = os.path.dirname(log_name)

    root = MENU_ROOT

    sep_item = "amenu <silent> %(sep_priority)s %(root)s.-SepHLD- :" % locals()
    menus.append(sep_item)

    if sys.platform == "darwin":
        open_log_cmd = "!open -a MacVim"
        reveal_log_cmd = "!open"
    else:
        open_log_cmd = "edit"

    open_item = "amenu <silent> %(open_priority)s %(root)s.debug.Open\ Log<Tab>%(log_name_label)s :%(open_log_cmd)s %(log_name)s<CR>" % locals()
    menus.append(open_item)

    explore_item = "amenu <silent> %(texplore_priority)s %(root)s.debug.Explore\ in\ Vim<Tab>%(log_dir)s :Texplore %(log_dir)s<CR>" % locals()
    menus.append(explore_item)

    try:
        reveal_item = "amenu <silent> %(explore_priority)s %(root)s.debug.Explore\ in\ System<Tab>%(log_dir)s :%(reveal_log_cmd)s %(log_dir)s<CR>" % locals()
        menus.append(reveal_item)
    except KeyError:
        pass    # no reveal item for this platform

def get_source_script(line):
    """Extract the source script from the line and return the bundle."""

    script_path = line.replace(SOURCE_LINE, "").strip()

    return bundles.get(expand_home(script_path))

def parse_scriptnames():
    """Extract the bundles (aka scriptnames/plugins)."""

    global scriptnames

    scriptnames = scriptnames.strip().split("\n")

    for line in scriptnames:
        # strip leading indexes
        matches = SCRIPTNAME_PATTERN.match(line)

        order = matches.group("order")
        path = matches.group("path")

        init_bundle(expand_home(path), order)

def parse_commands(commands):
    """Extract the commands."""

    # delete the listing header
    commands = commands[1:]

    for i, line in enumerate(commands):
        # begin with command lines
        if not line.find(SOURCE_LINE) > -1:
            matches = COMMAND_PATTERN.match(line)

            try:
                command = matches.group("name")
            except AttributeError:
                errors.append("parse_commands: no command name found in command '%(line)s'" % locals())
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
                errors.append("parse_command: source line not found for command '%(line)s'" % locals())
                continue
            except TypeError:
                errors.append("parse_command: source script not initialised for command '%(line)s'" % locals())
                continue

def parse_modes(mode):
    """Return a list of all the modes."""

    # restore empty mode to original value (space)
    if not mode:
        mode = " "

    # cater for multiple modes
    modes = list(mode)

    # translate to mode descriptions
    modes = list(map(MODE_MAP.get, modes))

    return modes

def parse_mappings(mappings):
    """Extract the mappings."""

    for i, line in enumerate(mappings):
        # begin with mapping lines
        if not line.find(SOURCE_LINE) > -1:
            matches = MAPPING_PATTERN.match(line)

            try:
                lhs = matches.group("lhs")
            except AttributeError:
                errors.append("parse_mappings: lhs not found for mapping '%(line)s'" % locals())
                continue

            try:
                rhs = matches.group("rhs").strip()
            except AttributeError:
                errors.append("parse_mappings: rhs not found for mapping '%(line)s'" % locals())
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
                errors.append("parse_mappings: source line not found for mapping '%(line)s'" % locals())
                continue
            except TypeError:
                errors.append("parse_mappings: source script not initialised for mapping '%(line)s'" % locals())
                continue

def parse_abbreviations(abbreviations):
    """Extract the abbreviations."""

    for i, line in enumerate(abbreviations):
        # begin with abbreviation lines
        if not line.find(SOURCE_LINE) > -1:
            matches = ABBREV_PATTERN.match(line)

            try:
                lhs = matches.group("lhs")
            except AttributeError:
                errors.append("parse_abbreviations: lhs not found for abbreviation '%(line)s'" % locals())
                continue

            try:
                rhs = matches.group("rhs").strip()
            except AttributeError:
                errors.append("parse_abbreviations: rhs not found for abbreviation '%(line)s'" % locals())
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
                errors.append("parse_abbreviations: source line not found for abbreviation '%(line)s'" % locals())
                continue
            except TypeError:
                errors.append("parse_mappings: source script not initialised for abbreviation '%(line)s'" % locals())
                continue

def parse_functions(functions):
    """Extract the functions."""

    for i, line in enumerate(functions):
        # begin with function lines
        if not line.find(SOURCE_LINE) > -1:
            function = line.split("function ")[1]

            # get the source script from the next list item
            source_script = get_source_script(functions[i + 1])

            # add the function to the source script (public functions only)
            if not function.startswith("<SNR>"):
                source_script["functions"].append(function)

def parse_highlights(highlights):
    """Extract the highlights."""

    for i, line in enumerate(highlights):
        # begin with highlight lines
        if not line.find(SOURCE_LINE) > -1:
            matches = HIGHLIGHT_PATTERN.match(line)

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

def sanitise_menu(menu):
    """Escape special characters in vim menus."""
    return menu.replace("\\", "\\\\").replace("|", "\\|").replace(".", "\\.").replace(" ", "\\ ").replace("<", "\\<")

def expand_home(path):
    """Return the absolute home path for forward compatibility with later vim versions."""
    return os.getenv("HOME") + path[1:] if path.startswith("~") else path

def attach_menus():
    """Coordinate the action and attach the vim menus (minimising vim sphagetti)."""

    root = MENU_ROOT
    sep = os.linesep

    DEBUG_MSG = "See the '%(root)s > debug' menu for details.%(sep)s" % locals()
    ERROR_MSG = "Headlights encountered a critical error. %(DEBUG_MSG)s" % locals()

    if not DEBUG_MODE:
        DEBUG_MSG = "To enable debug mode, see :help headlights_debug_mode%(sep)s" % locals()

    WARNING_MSG = "Warning: Headlights failed to execute menu command. %(DEBUG_MSG)s" % locals()

    try:
        parse_scriptnames()

        # parse the menu categories with the similarly named functions
        for key in iter(list(categories.keys())):
            if categories[key]:
                function = globals()["parse_" + key]
                function(categories[key].strip().split("\n"))

        for path, properties in iter(list(bundles.items())):
            name = properties["name"]

            spillover = sanitise_menu(get_spillover(name, path))

            name = sanitise_menu(name)

            prefix = "%(root)s.%(spillover)s.%(name)s." % locals()

            gen_menus(name, prefix, path, properties)

            # duplicate local buffer menus for convenience
            if bundles[path]["buffer"]:
                prefix = "%(root)s.⁣⁣buffer.%(name)s." % locals()
                gen_menus(name, prefix, path, properties)

    # recover (somewhat) gracefully
    except Exception:
        import traceback
        errors.insert(0, traceback.format_exc())
        sys.stdout.write(ERROR_MSG)
        do_debug()

    finally:
        if DEBUG_MODE:
            do_debug()

    menus.sort(key=lambda menu: menu.lower())

    # attach the vim menus
    list(map(vim.command, menus))
    # import cProfile
    # DEBUG_MODE = False
    # cProfile.runctx("map(vim.command, menus)", globals(), locals())

def do_debug():
    """Attach the debug menu and write the log file."""

    import tempfile
    import platform

    LOGNAME_PREFIX = "headlights_"
    LOGNAME_SUFFIX = ".log"

    log_file = tempfile.NamedTemporaryFile(prefix=LOGNAME_PREFIX, suffix=LOGNAME_SUFFIX, delete=False)

    gen_debug_menu(log_file.name)

    date = time.ctime()
    platform = platform.platform()
    errors_ = "\n".join(errors)
    scriptnames_ = "\n".join(scriptnames)
    categories_ = "\n\n".join("%s:%s" % (key.upper(), categories[key]) for key in iter(list(categories.keys())))
    menus_ = "\n".join(menus)
    vim_time = vim_execution_time
    python_time = time.time() - start_time

    log_file.write("""Headlights -- Vim Debug Log

DATE: %(date)s
PLATFORM: %(platform)s

This is the debug log for Headlights <https://github.com/mbadran/headlights/>
For details on how to raise a GitHub issue, see :help headlights-issues
Don't forget to disable debug mode when you're done!

ERRORS:
%(errors_)s

SCRIPTNAMES:
%(scriptnames_)s

%(categories_)s

MENUS:
%(menus_)s

Headlights vim code executed in %(vim_time).2f seconds
Headlights python code executed in %(python_time).2f seconds
""" % locals())

    log_file.close()
