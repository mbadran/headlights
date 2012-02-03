# encoding: utf-8

class Headlights():
    """
    Python helper class for headlights.vim
    Version: 1.4
    """

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

    sanitise_menu = lambda self, menu: menu.replace("\\", "\\\\").replace("|", "\\|").replace(".", "\\.").replace(" ", "\\ ").replace("<", "\\<")

    # required for forwards vim compatibility
    expand_home = lambda self, path: os.getenv("HOME") + path[1:] if path.startswith("~") else path

    bundles = {}
    menus = []
    errors = []

    def __init__(self, vim_time, scriptnames, **categories):
        """Initialise the default settings."""

        self.time_start = time.time()
        self.vim_time = float(vim_time)
        self.scriptnames = scriptnames
        self.categories = categories

        # for quick profiling, disable
        self.attach_menus()

        # for quick profiling, enable
        # import cProfile
        # self.DEBUG_MODE = False
        # cProfile.runctx("self.attach_menus()", globals(), locals())

    def init_bundle(self, path, order):
        """Initialise new bundles (aka scripts/plugins)."""

        # use the filename as the default bundle name
        name = os.path.splitext(os.path.basename(path))[0]

        # use the file dir as the default bundle root
        root = os.path.dirname(path)

        if self.SMART_MENUS:
            # find the actual bundle root (ignoring runtime bundles). break out of standard vim dirs, if necessary.
            if not root.lower().find("/runtime/") > -1:
                for pattern in self.VIM_DIR_PATTERNS:
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
                for key in iter(list(self.bundles.keys())):
                    if root == self.bundles[key]["root"]:
                        # if we have a match, group the bundles together by the previous name
                        name = self.bundles[key]["name"]
                        break

        self.bundles[path] = {
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

        return self.bundles[path]

    def get_spillover(self, name, path):
        """Return an appropriate menu category/spillover parent."""

        # a catch all, just in case
        spillover = "⁣other"

        name = name.strip()

        # use empty chars (looks like space) to move menus to the bottom
        # and exclude vimrc files from buffer local menus (for simplicity)
        if self.bundles[path]["name"].endswith("vimrc"):
            spillover = "⁣vimrc"
        elif path.lower().find("/runtime/") > -1:
            spillover = "⁣runtime"
        else:
            for pattern, category in list(self.MENU_SPILLOVER_PATTERNS.items()):
                if pattern.match(name):
                    spillover = category
                    break

        return spillover

    def gen_menus(self, name, prefix, path, properties):
            # this needs to be first so sort() can get the script order right
            self.gen_help_menu(name, prefix)

            if self.SHOW_FILES:
                self.gen_files_menu(path, prefix, properties["order"])

            if len(properties["commands"]) > 0:
                self.gen_commands_menu(properties["commands"], prefix)

            if len(properties["mappings"]) > 0:
                self.gen_mappings_menu(properties["mappings"], prefix)

            if len(properties["abbreviations"]) > 0:
                self.gen_abbreviations_menu(properties["abbreviations"], prefix)

            if len(properties["functions"]) > 0:
                self.gen_functions_menu(properties["functions"], prefix)

            if len(properties["highlights"]) > 0:
                self.gen_highlights_menu(properties["highlights"], prefix)

    def gen_commands_menu(self, commands, prefix):
        """Add command menus."""

        item_priority = "9997.120"

        for command in commands:
            name = self.sanitise_menu(command[0])
            definition = self.sanitise_menu(command[1])

            command_item = "amenu <silent> %(item_priority)s %(prefix)sCommands.%(name)s<Tab>Run\ command :%(name)s<CR>" % locals()
            self.menus.append(command_item)

    def gen_files_menu(self, path, prefix, load_order):
        """Add file menus."""

        item_priority = "9997.160"

        file_path = trunc_file_path = self.sanitise_menu(path)
        file_dir_path = self.sanitise_menu(os.path.dirname(path))

        # unescape dots so path commands can be run
        file_path_cmd = file_path.replace("\\.", ".")
        file_dir_path_cmd = file_dir_path.replace("\\.", ".")

        if len(file_path) > self.MENU_TRUNC_LIMIT:
            trunc_file_path = "<" + self.sanitise_menu(path[-self.MENU_TRUNC_LIMIT:])

        if sys.platform == "darwin":
            # make the file appear in the "file > open recent" menu
            # also, honour the macvim option, "open files from applications"
            # (this doesn't take into account terminal vim, but menu access there is probably uncommon)
            open_cmd = "!open -a MacVim"
            reveal_cmd = "!open"
        else:
            open_cmd = "edit"

        open_item = "amenu <silent> %(item_priority)s.10 %(prefix)sFiles.%(trunc_file_path)s.Open\ File<Tab>%(file_path)s :%(open_cmd)s %(file_path_cmd)s<CR>" % locals()
        self.menus.append(open_item)

        explore_item = "amenu <silent> %(item_priority)s.20 %(prefix)sFiles.%(trunc_file_path)s.Explore\ in\ Vim<Tab>%(file_dir_path)s :Texplore %(file_dir_path_cmd)s<CR>" % locals()
        self.menus.append(explore_item)

        try:
            reveal_item = "amenu <silent> %(item_priority)s.30 %(prefix)sFiles.%(trunc_file_path)s.Explore\ in\ System<Tab>%(file_dir_path)s :%(reveal_cmd)s %(file_dir_path_cmd)s<CR>" % locals()
            self.menus.append(reveal_item)
        except KeyError:
            pass    # no reveal item for this platform

        if self.SHOW_LOAD_ORDER:
            sep_item = "amenu <silent> %(item_priority)s.40 %(prefix)sFiles.%(trunc_file_path)s.-Sep1- :" % locals()
            self.menus.append(sep_item)

            order_item = "amenu <silent> %(item_priority)s.50 %(prefix)sFiles.%(trunc_file_path)s.Order:\ %(load_order)s :" % locals()
            self.menus.append(order_item)
            disabled_item = "amenu <silent> disable %(prefix)sFiles.%(trunc_file_path)s.Order:\ %(load_order)s" % locals()
            self.menus.append(disabled_item)

    def gen_mappings_menu(self, mappings, prefix):
        """Add mapping menus."""

        item_priority = "9997.130"

        for mode, lhs, rhs in mappings:
            mode = self.sanitise_menu(mode)
            lhs = self.sanitise_menu(lhs)
            rhs = self.sanitise_menu(rhs)

            mapping_item = "amenu <silent> %(item_priority)s %(prefix)sMappings.%(mode)s.%(lhs)s<Tab>%(rhs)s :" % locals()
            self.menus.append(mapping_item)
            disabled_item = "amenu <silent> disable %(prefix)sMappings.%(mode)s.%(lhs)s" % locals()
            self.menus.append(disabled_item)

    def gen_abbreviations_menu(self, abbreviations, prefix):
        """Add abbreviation menus."""

        item_priority = "9997.140"

        for mode, lhs, rhs in abbreviations:
            mode = self.sanitise_menu(mode)
            lhs = trunc_lhs = self.sanitise_menu(lhs)
            rhs = self.sanitise_menu(rhs)

            if len(lhs) > self.MENU_TRUNC_LIMIT:
                trunc_lhs = lhs[:self.MENU_TRUNC_LIMIT] + ">"

            # prefix mode with an invisible char so vim can create mode menus separate from mappings'
            abbr_item = "amenu <silent> %(item_priority)s %(prefix)s⁣Abbreviations.%(mode)s.%(trunc_lhs)s<Tab>%(rhs)s :" % locals()
            self.menus.append(abbr_item)
            disabled_item = "amenu <silent> disable %(prefix)s⁣Abbreviations.%(mode)s.%(trunc_lhs)s" % locals()
            self.menus.append(disabled_item)

    def gen_help_menu(self, name, prefix):
        """Add help menus."""

        help_priority = "9997.100"
        sep_priority = "9997.110"

        help_item = "amenu <silent> %(help_priority)s %(prefix)sHelp :help %(name)s<CR>" % locals()
        self.menus.append(help_item)

        sep_item = "amenu <silent> %(sep_priority)s %(prefix)s-Sep1- :" % locals()
        self.menus.append(sep_item)

    def gen_functions_menu(self, functions, prefix):
        """Add function menus."""

        item_priority = "9997.150"

        for function in functions:
            trunc_function = self.sanitise_menu(function)
            function_label = ""

            # only show a label if the function name is truncated
            if len(function) > self.MENU_TRUNC_LIMIT:
                function_label = trunc_function
                trunc_function = trunc_function[:self.MENU_TRUNC_LIMIT] + ">"

            function_item = "amenu <silent> %(item_priority)s %(prefix)sFunctions.%(trunc_function)s<Tab>%(function_label)s :" % locals()
            self.menus.append(function_item)
            disabled_item = "amenu <silent> disable %(prefix)sFunctions.%(trunc_function)s" % locals()
            self.menus.append(disabled_item)

    def gen_highlights_menu(self, highlights, prefix):
        """Add highlight menus."""

        item_priority = "9997.150"

        for group, terminal_list in highlights:
            group = self.sanitise_menu(group)

            for terminal, attribute_list in iter(list(terminal_list.items())):
                terminal = self.sanitise_menu(terminal)

                for attribute in attribute_list:
                    attribute = self.sanitise_menu(attribute)
                    highlight_item = "amenu <silent> %(item_priority)s %(prefix)sHighlights.%(group)s.%(terminal)s.%(attribute)s<Tab>Copy\ to\ clipboard :let @* = '%(attribute)s'<CR>" % locals()
                    self.menus.append(highlight_item)

    def gen_debug_menu(self, log_name):
        """Add debug menus."""

        sep_priority = "9997.300"
        open_priority = "9997.310"
        texplore_priority = "9997.320"
        explore_priority = "9997.330"

        log_name_label = self.sanitise_menu(log_name)
        log_dir = os.path.dirname(log_name)

        root = self.MENU_ROOT

        sep_item = "amenu <silent> %(sep_priority)s %(root)s.-SepHLD- :" % locals()
        self.menus.append(sep_item)

        if sys.platform == "darwin":
            open_log_cmd = "!open -a MacVim"
            reveal_log_cmd = "!open"
        else:
            open_log_cmd = "edit"

        open_item = "amenu <silent> %(open_priority)s %(root)s.debug.Open\ Log<Tab>%(log_name_label)s :%(open_log_cmd)s %(log_name)s<CR>" % locals()
        self.menus.append(open_item)

        explore_item = "amenu <silent> %(texplore_priority)s %(root)s.debug.Explore\ in\ Vim<Tab>%(log_dir)s :Texplore %(log_dir)s<CR>" % locals()
        self.menus.append(explore_item)

        try:
            reveal_item = "amenu <silent> %(explore_priority)s %(root)s.debug.Explore\ in\ System<Tab>%(log_dir)s :%(reveal_log_cmd)s %(log_dir)s<CR>" % locals()
            self.menus.append(reveal_item)
        except KeyError:
            pass    # no reveal item for this platform

    def get_source_script(self, line):
        """Extract the source script from the line and return the bundle."""

        script_path = line.replace(self.SOURCE_LINE, "").strip()

        return self.bundles.get(self.expand_home(script_path))

    def parse_scriptnames(self):
        """Extract the bundles (aka scripts/plugins)."""

        self.scriptnames = self.scriptnames.strip().split("\n")

        for line in self.scriptnames:
            # strip leading indexes
            matches = self.SCRIPTNAME_PATTERN.match(line)

            order = matches.group("order")
            path = matches.group("path")

            self.init_bundle(self.expand_home(path), order)

    def parse_commands(self, commands):
        """Extract the commands."""

        # delete the listing header
        commands = commands[1:]

        for i, line in enumerate(commands):
            # begin with command lines
            if not line.find(self.SOURCE_LINE) > -1:
                matches = self.COMMAND_PATTERN.match(line)

                try:
                    command = matches.group("name")
                except AttributeError:
                    self.errors.append("parse_commands: no command name found in command '%(line)s'" % locals())
                    continue

                definition = matches.group("definition")

                # a vim command can be declared with no definition (just a :)
                try:
                    definition = definition.strip()
                except AttributeError:
                    definition = ""

                # get the source script from the next list item
                try:
                    source_script = self.get_source_script(commands[i + 1])

                    if matches.group("buffer"):
                        # command = "@ " + command
                        source_script["buffer"] = True

                    source_script["commands"].append([command, definition])

                except IndexError:
                    self.errors.append("parse_command: source line not found for command '%(line)s'" % locals())
                    continue
                except TypeError:
                    self.errors.append("parse_command: source script not initialised for command '%(line)s'" % locals())
                    continue

    def parse_modes(self, mode):
        """Return a list of all the modes."""

        # restore empty mode to original value (space)
        if not mode:
            mode = " "

        # cater for multiple modes
        modes = list(mode)

        # translate to mode descriptions
        modes = [self.MODE_MAP.get(mode) for mode in modes]

        return modes

    def parse_mappings(self, mappings):
        """Extract the mappings."""

        for i, line in enumerate(mappings):
            # begin with mapping lines
            if not line.find(self.SOURCE_LINE) > -1:
                matches = self.MAPPING_PATTERN.match(line)

                try:
                    lhs = matches.group("lhs")
                except AttributeError:
                    self.errors.append("parse_mappings: lhs not found for mapping '%(line)s'" % locals())
                    continue

                try:
                    rhs = matches.group("rhs").strip()
                except AttributeError:
                    self.errors.append("parse_mappings: rhs not found for mapping '%(line)s'" % locals())
                    continue

                modes = self.parse_modes(matches.group("modes"))

                # get the source script from the next list item
                try:
                    source_script = self.get_source_script(mappings[i + 1])

                    # flag the bundle as buffer local, and prepend an indicator to the mapping
                    if matches.group("buffer"):
                        # lhs = "@ " + lhs
                        source_script["buffer"] = True

                    # add the mapping to the source script
                    for mode in modes:
                        source_script["mappings"].append([mode, lhs, rhs])

                except IndexError:
                    self.errors.append("parse_mappings: source line not found for mapping '%(line)s'" % locals())
                    continue
                except TypeError:
                    self.errors.append("parse_mappings: source script not initialised for mapping '%(line)s'" % locals())
                    continue

    def parse_abbreviations(self, abbreviations):
        """Extract the abbreviations."""

        for i, line in enumerate(abbreviations):
            # begin with abbreviation lines
            if not line.find(self.SOURCE_LINE) > -1:
                matches = self.ABBREV_PATTERN.match(line)

                try:
                    lhs = matches.group("lhs")
                except AttributeError:
                    self.errors.append("parse_abbreviations: lhs not found for abbreviation '%(line)s'" % locals())
                    continue

                try:
                    rhs = matches.group("rhs").strip()
                except AttributeError:
                    self.errors.append("parse_abbreviations: rhs not found for abbreviation '%(line)s'" % locals())
                    continue

                modes = self.parse_modes(matches.group("modes"))

                # get the source script from the next list item
                try:
                    source_script = self.get_source_script(abbreviations[i + 1])

                    # flag the bundle as buffer local, and prepend an indicator to the mapping
                    if matches.group("buffer"):
                        # lhs = "@ " + lhs
                        source_script["buffer"] = True

                    # add the abbreviation to the source script
                    for mode in modes:
                        source_script["abbreviations"].append([mode, lhs, rhs])

                except IndexError:
                    self.errors.append("parse_abbreviations: source line not found for abbreviation '%(line)s'" % locals())
                    continue
                except TypeError:
                    self.errors.append("parse_mappings: source script not initialised for abbreviation '%(line)s'" % locals())
                    continue

    def parse_functions(self, functions):
        """Extract the functions."""

        for i, line in enumerate(functions):
            # begin with function lines
            if not line.find(self.SOURCE_LINE) > -1:
                function = line.split("function ")[1]

                # get the source script from the next list item
                source_script = self.get_source_script(functions[i + 1])

                # add the function to the source script (public functions only)
                if not function.startswith("<SNR>"):
                    source_script["functions"].append(function)

    def parse_highlights(self, highlights):
        """Extract the highlights."""

        for i, line in enumerate(highlights):
            # begin with highlight lines
            if not line.find(self.SOURCE_LINE) > -1:
                matches = self.HIGHLIGHT_PATTERN.match(line)

                group = matches.group("group")
                arguments = matches.group("arguments")

                if not arguments.startswith("cleared") and not arguments.startswith("links to "):
                    # get the source script from the next list item
                    source_script = self.get_source_script(highlights[i + 1])

                    terminal_list = {}

                    for argument in arguments.split(" "):
                        terminal, attributes = argument.split("=")

                        attribute_list = attributes.split(",")

                        terminal_list[terminal] = attribute_list

                    # add the highlights to the source script
                    source_script["highlights"].append([group, terminal_list])

    def attach_menus(self):
        """Coordinate the action and attach the vim menus (minimising vim sphagetti)."""

        root = self.MENU_ROOT
        sep = os.linesep

        DEBUG_MSG = "See the '%(root)s > debug' menu for details.%(sep)s" % locals()
        ERROR_MSG = "Headlights encountered a critical error. %(DEBUG_MSG)s" % locals()

        if not self.DEBUG_MODE:
            DEBUG_MSG = "To enable debug mode, see :help headlights_debug_mode%(sep)s" % locals()

        WARNING_MSG = "Warning: Headlights failed to execute menu command. %(DEBUG_MSG)s" % locals()

        try:
            self.parse_scriptnames()

            # parse the menu categories with the similarly named functions
            for key in iter(list(self.categories.keys())):
                if self.categories[key]:
                    function = getattr(self, "parse_" + key)
                    function(self.categories[key].strip().split("\n"))

            for path, properties in iter(list(self.bundles.items())):
                name = properties["name"]

                spillover = self.sanitise_menu(self.get_spillover(name, path))

                name = self.sanitise_menu(name)

                prefix = "%(root)s.%(spillover)s.%(name)s." % locals()

                self.gen_menus(name, prefix, path, properties)

                # duplicate local buffer menus for convenience
                if self.bundles[path]["buffer"]:
                    prefix = "%(root)s.⁣⁣buffer.%(name)s." % locals()
                    self.gen_menus(name, prefix, path, properties)

        # recover (somewhat) gracefully
        except Exception:
            import traceback
            self.errors.insert(0, traceback.format_exc())
            sys.stdout.write(ERROR_MSG)
            self.do_debug()
            pass

        finally:
            if self.DEBUG_MODE:
                self.do_debug()

        self.menus.sort(key=lambda menu: menu.lower())

        # only reset the buffer submenu, if it exists (faster than resetting everything, since vim will only attach new menus)
        # disadvantage: new menus (for eg, via autoload) will go to the bottom, messing up the alphabetical order
        vim.command("try | aunmenu %(root)s.⁣⁣buffer | catch /E329/ | endtry" % locals())
        #import cProfile
        #self.DEBUG_MODE = False
        #cProfile.runctx("vim.command('try | aunmenu %(root)s.⁣⁣buffer | catch /E329/ | endtry' % locals())", globals(), locals())

        # attach the vim menus
        [vim.command("%(menu_command)s" % locals()) for menu_command in self.menus]
        #import cProfile
        #self.DEBUG_MODE = False
        #cProfile.runctx("[vim.command('%(menu_command)s' % locals()) for menu_command in self.menus]", globals(), locals())

    def do_debug(self):
        """Attach the debug menu and write the log file."""

        import tempfile
        import platform

        LOGNAME_PREFIX = "headlights_"
        LOGNAME_SUFFIX = ".log"

        log_file = tempfile.NamedTemporaryFile(prefix=LOGNAME_PREFIX, suffix=LOGNAME_SUFFIX, delete=False)

        self.gen_debug_menu(log_file.name)

        date = time.ctime()
        platform = platform.platform()
        errors = "\n".join(self.errors)
        scriptnames = "\n".join(self.scriptnames)
        categories = "\n\n".join("%s:%s" % (key.upper(), self.categories[key]) for key in iter(list(self.categories.keys())))
        menus = "\n".join(self.menus)
        vim_time = self.vim_time
        python_time = time.time() - self.time_start

        log_file.write("""Headlights -- Vim Debug Log

DATE: %(date)s
PLATFORM: %(platform)s

This is the debug log for Headlights <https://github.com/mbadran/headlights/>
For details on how to raise a GitHub issue, see :help headlights-issues
Don't forget to disable debug mode when you're done!

ERRORS:
%(errors)s

SCRIPTNAMES:
%(scriptnames)s

%(categories)s

MENUS:
%(menus)s

Headlights vim code executed in %(vim_time).2f seconds
Headlights python code executed in %(python_time).2f seconds
""" % locals())

        log_file.close()
