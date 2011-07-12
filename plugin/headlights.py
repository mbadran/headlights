# encoding: utf-8

#import os, re, time, sys       # imported in headlights.vim

class Headlights():
    """
    Python helper class for headlights.vim
    Version: 1.2
    """
    bundles = {}
    menus = []
    errors = []

    MODE_MAP = {
        " ": "Normal, Visual, Select, Operator-pending",
        "n": "Normal",
        "v": "Visual and Select",
        "s": "Select",
        "x": "Visual",
        "o": "Operator-pending",
        "!": "Insert and Command-line",
        "i": "Insert",
        "l": ":lmap",
        "c": "Command-line"
    }

    SOURCE_LINE = "Last set from"

    MENU_TRUNC_LIMIT = 30

    sanitise_menu = lambda self, menu: menu.replace("\\", "\\\\").replace("|", "\\|").replace(".", "\\.").replace(" ", "\\ ").replace("<", "\\<")

    # required for forwards vim compatibility
    expand_home = lambda self, path: os.getenv("HOME") + path[1:] if path.startswith("~") else path

    MENU_SPILLOVER_PATTERNS = {
        re.compile(r"\.?_?\d", re.IGNORECASE): "0 - 9",
        re.compile(r"\.?_?[a-i]", re.IGNORECASE): "a - i",
        re.compile(r"\.?_?[j-r]", re.IGNORECASE): "j - r",
        re.compile(r"\.?_?[s-z]", re.IGNORECASE): "s - z"
    }

    def __init__(self, menu_root, debug_mode, vim_time, enable_files, scriptnames, **categories):
        """Initialise the default settings."""

        self.time_start = time.time()
        self.menu_root = menu_root
        self.debug_mode = bool(int(debug_mode))
        self.vim_time = float(vim_time)
        self.enable_files = bool(int(enable_files))
        self.scriptnames = scriptnames
        self.categories = categories

        # for quick profiling, disable
        self.attach_menus()

        # for quick profiling, enable
        #import cProfile
        #self.debug_mode = False
        #cProfile.runctx("self.attach_menus()", globals(), locals())

    def init_bundle(self, path):
        """Initialise new bundles (aka scripts/plugins)."""

        name = os.path.splitext(os.path.basename(path))[0]

        self.bundles[path] = {"name": name, "commands": [], "mappings": [], "abbreviations": [], "functions": [], "buffer": False}

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
        elif self.bundles[path]["buffer"]:
            spillover = "⁣⁣buffer"
        elif path.lower().find("runtime") > -1:
            spillover = "⁣runtime"
        else:
            for pattern, category in list(self.MENU_SPILLOVER_PATTERNS.items()):
                if pattern.match(name):
                    spillover = category
                    break

        return spillover

    def gen_menus(self):
        """Add the root menu and coordinate menu categories."""

        root = self.menu_root

        for path, properties in iter(self.bundles.items()):
            name = properties["name"]

            spillover = self.sanitise_menu(self.get_spillover(name, path))

            name = self.sanitise_menu(name)

            prefix = "%(root)s.%(spillover)s.%(name)s." % locals()

            # this needs to be first so sort() can get the script order right
            self.gen_help_menu(name, prefix)

            if self.enable_files:
                self.gen_files_menu(path, prefix)

            if len(properties["commands"]) > 0:
                self.gen_commands_menu(properties["commands"], prefix)

            if len(properties["mappings"]) > 0:
                self.gen_mappings_menu(properties["mappings"], prefix)

            if len(properties["abbreviations"]) > 0:
                self.gen_abbreviations_menu(properties["abbreviations"], prefix)

            if len(properties["functions"]) > 0:
                self.gen_functions_menu(properties["functions"], prefix)

    def gen_commands_menu(self, commands, prefix):
        """Add command menus."""

        sep_priority = "9997.110"
        title_priority = "9997.120"
        item_priority = "9997.130"

        sep_item = "amenu %(sep_priority)s %(prefix)s-Sep1- :" % locals()
        self.menus.append(sep_item)

        title_item = "amenu %(title_priority)s %(prefix)sCommands :" % locals()
        self.menus.append(title_item)
        disabled_item = "amenu disable %(prefix)sCommands" % locals()
        self.menus.append(disabled_item)

        for command in commands:
            name = self.sanitise_menu(command[0])
            definition = self.sanitise_menu(command[1])

            command_item = "amenu %(item_priority)s %(prefix)s%(name)s<Tab>:%(definition)s :%(name)s<CR>" % locals()
            self.menus.append(command_item)

    def gen_files_menu(self, path, prefix):
        """Add file menus."""

        sep_priority = "9997.220"
        title_priority = "9997.230"
        item_priority = "9997.240"

        sep_item = "amenu %(sep_priority)s %(prefix)s-Sep3- :" % locals()
        self.menus.append(sep_item)

        title_item = "amenu %(title_priority)s %(prefix)sFiles :" % locals()
        self.menus.append(title_item)
        disabled_item = "amenu disable %(prefix)sFiles" % locals()
        self.menus.append(disabled_item)

        file_path = trunc_file_path = self.sanitise_menu(path)
        file_dir_path = self.sanitise_menu(os.path.dirname(path))

        # unescape dots so path commands can be run
        file_path_cmd = file_path.replace("\\.", ".")
        file_dir_path_cmd = file_dir_path.replace("\\.", ".")

        if len(file_path) > self.MENU_TRUNC_LIMIT:
            trunc_file_path = "<" + self.sanitise_menu(path[-self.MENU_TRUNC_LIMIT:])

        if sys.platform == "darwin":
            # make the file appear in the "file > open recent" menu
            # also, honour the "open files from applications" option
            # (this doesn't take into account terminal vim, but menu access there is probably unlikely)
            open_cmd = "!open -a MacVim"
            reveal_cmd = "!open"
        #elif sys.platform == "win32":
            #open_cmd = "!start gvim"
            #reveal_cmd = "!start"
        #elif sys.platform == "linux2":
            #open_cmd = "!xdg-open vim"
            #reveal_cmd = "!xdg-open"
        else:
            open_cmd = "edit"

        open_item = "amenu %(item_priority)s.10 %(prefix)s%(trunc_file_path)s.Open\ File<Tab>%(file_path)s :%(open_cmd)s %(file_path_cmd)s<CR>" % locals()
        self.menus.append(open_item)

        explore_item = "amenu %(item_priority)s.20 %(prefix)s%(trunc_file_path)s.Explore\ in\ Vim<Tab>%(file_dir_path)s :Texplore %(file_dir_path_cmd)s<CR>" % locals()
        self.menus.append(explore_item)

        try:
            reveal_item = "amenu %(item_priority)s.30 %(prefix)s%(trunc_file_path)s.Explore\ in\ System<Tab>%(file_dir_path)s :%(reveal_cmd)s %(file_dir_path_cmd)s<CR>" % locals()
            self.menus.append(reveal_item)
        except KeyError:
            pass    # no reveal item for this platform

    def gen_mappings_menu(self, mappings, prefix):
        """Add mapping menus."""

        sep_priority = "9997.140"
        title_priority = "9997.150"
        item_priority = "9997.160"

        sep_item = "amenu %(sep_priority)s %(prefix)s-Sep2- :" % locals()
        self.menus.append(sep_item)

        title_item = "amenu %(title_priority)s %(prefix)sMappings :" % locals()
        self.menus.append(title_item)
        disabled_item = "amenu disable %(prefix)sMappings" % locals()
        self.menus.append(disabled_item)

        for mode, lhs, rhs in mappings:
            mode = self.sanitise_menu(mode)
            lhs = self.sanitise_menu(lhs)
            rhs = self.sanitise_menu(rhs)

            mapping_item = "amenu %(item_priority)s %(prefix)s%(mode)s.%(lhs)s<Tab>%(rhs)s :" % locals()
            self.menus.append(mapping_item)
            disabled_item = "amenu disable %(prefix)s%(mode)s.%(lhs)s" % locals()
            self.menus.append(disabled_item)

    def gen_abbreviations_menu(self, abbreviations, prefix):
        """Add abbreviation menus."""

        sep_priority = "9997.170"
        title_priority = "9997.180"
        item_priority = "9997.190"

        sep_item = "amenu %(sep_priority)s %(prefix)s-Sep4- :" % locals()
        self.menus.append(sep_item)

        title_item = "amenu %(title_priority)s %(prefix)sAbbreviations :" % locals()
        self.menus.append(title_item)
        disabled_item = "amenu disable %(prefix)sAbbreviations" % locals()
        self.menus.append(disabled_item)

        for mode, lhs, rhs in abbreviations:
            mode = self.sanitise_menu(mode)
            lhs = trunc_lhs = self.sanitise_menu(lhs)
            rhs = self.sanitise_menu(rhs)

            if len(lhs) > self.MENU_TRUNC_LIMIT:
                trunc_lhs = lhs[:self.MENU_TRUNC_LIMIT] + ">"

            # prefix mode with an invisible char so vim can create mode menus separate from mappings'
            abbr_item = "amenu %(item_priority)s %(prefix)s⁣%(mode)s.%(trunc_lhs)s<Tab>%(rhs)s :<CR>" % locals()
            self.menus.append(abbr_item)
            disabled_item = "amenu disable %(prefix)s⁣%(mode)s.%(trunc_lhs)s" % locals()
            self.menus.append(disabled_item)

    def gen_help_menu(self, name, prefix):
        """Add help menus."""

        help_priority = "9997.100"

        help_item = "amenu %(help_priority)s %(prefix)sHelp<Tab>help\ %(name)s :help %(name)s<CR>" % locals()
        self.menus.append(help_item)

    def gen_functions_menu(self, functions, prefix):
        """Add function menus."""

        sep_priority = "9997.200"
        item_priority = "9997.210"

        sep_item = "amenu %(sep_priority)s %(prefix)s-Sep6- :" % locals()
        self.menus.append(sep_item)

        for function in functions:
            trunc_function = self.sanitise_menu(function)
            function_label = ""

            # only show a label if the function name is truncated
            if len(function) > self.MENU_TRUNC_LIMIT:
                function_label = trunc_function
                trunc_function = trunc_function[:self.MENU_TRUNC_LIMIT] + ">"

            function_item = "amenu %(item_priority)s %(prefix)sFunctions.%(trunc_function)s<Tab>%(function_label)s :<CR>" % locals()
            self.menus.append(function_item)
            disabled_item = "amenu disable %(prefix)sFunctions.%(trunc_function)s" % locals()
            self.menus.append(disabled_item)

    def gen_debug_menu(self, log_name):
        """Add debug menus."""

        sep_priority = "9997.300"
        open_priority = "9997.310"
        texplore_priority = "9997.320"
        explore_priority = "9997.330"

        log_name_label = self.sanitise_menu(log_name)
        log_dir = os.path.dirname(log_name)

        root = self.menu_root

        sep_item = "amenu %(sep_priority)s %(root)s.-SepHLD- :" % locals()
        self.menus.append(sep_item)

        if sys.platform == "darwin":
            open_log_cmd = "!open -a MacVim"
            reveal_log_cmd = "!open"
        #elif sys.platform == "win32":
            #open_log_cmd = "!start gvim"
            #reveal_log_cmd = "!start"
        #elif sys.platform == "linux2":
            #open_log_cmd = "!xdg-open vim"
            #reveal_log_cmd = "!xdg-open"
        else:
            open_log_cmd = "edit"

        open_item = "amenu %(open_priority)s %(root)s.debug.Open\ Log<Tab>%(log_name_label)s :%(open_log_cmd)s %(log_name)s<CR>" % locals()
        self.menus.append(open_item)

        explore_item = "amenu %(texplore_priority)s %(root)s.debug.Explore\ in\ Vim<Tab>%(log_dir)s :Texplore %(log_dir)s<CR>" % locals()
        self.menus.append(explore_item)

        try:
            reveal_item = "amenu %(explore_priority)s %(root)s.debug.Explore\ in\ System<Tab>%(log_dir)s :%(reveal_log_cmd)s %(log_dir)s<CR>" % locals()
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

        pattern = re.compile(r"\s*\d+:\s")

        for path in self.scriptnames:
            # strip leading indexes
            path = pattern.sub("", path)

            self.init_bundle(self.expand_home(path))

    def parse_commands(self, commands):
        """Extract the commands."""

        pattern = re.compile(r'''
            ^
            (?P<bang>!)?
            \s*
            (?P<register>")?
            \s*
            (?P<buffer>b\s+)?
            (?P<name>[\S]+)
            \s+
            (?P<args>[01+?*])?
            \s*
            (?P<range>(\.|1c|%|0c))?
            \s*
            (?P<complete>(dir|file|buffer))?
            \s*
            :?
            (?P<definition>.+)?
            $
            ''', re.VERBOSE | re.IGNORECASE)

        # delete the listing header
        commands = commands[1:]

        for i, line in enumerate(commands):
            # begin with command lines
            if not line.find(self.SOURCE_LINE) > -1:
                matches = pattern.match(line)

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
                    source_script = self.get_source_script(commands[i+1])

                    if matches.group("buffer"):
                        command = "@ " + command
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

        pattern = re.compile(r'''
            ^
            (?P<modes>[nvsxo!ilc]+)?
            \s*
            (?P<lhs>[\S]+)
            \s+
            (?P<noremap>\*)?
            (?P<script>&)?
            (?P<buffer>@)?
            \s*
            (?P<rhs>.+)
            $
            ''', re.VERBOSE | re.IGNORECASE)

        for i, line in enumerate(mappings):
            # begin with mapping lines
            if not line.find(self.SOURCE_LINE) > -1:
                matches = pattern.match(line)

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
                    source_script = self.get_source_script(mappings[i+1])

                    # flag the bundle as buffer local, and prepend an indicator to the mapping
                    if matches.group("buffer"):
                        lhs = "@ " + lhs
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

        pattern = re.compile(r'''
            ^
            (?P<modes>[nvsxo!ilc]+)?
            \s*
            (?P<lhs>[\S]+)
            \s+
            (?P<noremap>\*)?
            (?P<script>&)?
            (?P<buffer>@)?
            \s*
            (?P<rhs>.+)
            $
            ''', re.VERBOSE | re.IGNORECASE)

        for i, line in enumerate(abbreviations):
            # begin with abbreviation lines
            if not line.find(self.SOURCE_LINE) > -1:
                matches = pattern.match(line)

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
                    source_script = self.get_source_script(abbreviations[i+1])

                    # flag the bundle as buffer local, and prepend an indicator to the mapping
                    if matches.group("buffer"):
                        lhs = "@ " + lhs
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
                source_script = self.get_source_script(functions[i+1])

                # add the function to the source script (public functions only)
                if not function.startswith("<SNR>"):
                    source_script["functions"].append(function)

    def attach_menus(self):
        """Coordinate the action and attach the vim menus (minimising vim sphagetti)."""

        root = self.menu_root
        sep = os.linesep

        DEBUG_MSG = "See the '%(root)s > debug' menu for details.%(sep)c" % locals()
        ERROR_MSG = "Headlights encountered a critical error. %(DEBUG_MSG)s" % locals()

        if not self.debug_mode:
            DEBUG_MSG = "To enable debug mode, see :help headlights_debug_mode%(sep)c" % locals()

        WARNING_MSG = "Warning: Headlights failed to execute menu command. %(DEBUG_MSG)s" % locals()

        try:
            self.parse_scriptnames()

            # parse the menu categories with the similarly named functions
            for key in iter(self.categories.keys()):
                if self.categories[key]:
                    function = getattr(self, "parse_" + key)
                    function(self.categories[key].strip().split("\n"))

            self.gen_menus()

        # recover (somewhat) gracefully
        except Exception:
            import traceback
            self.errors.insert(0, traceback.format_exc())
            sys.stdout.write(ERROR_MSG)
            self.do_debug()
            pass

        finally:
            if self.debug_mode:
                self.do_debug()

        self.menus.sort(key=lambda menu: menu.lower())

        # only reset the buffer submenu, if it exists
        # this is faster than resetting everything, as it seems that vim will only attach new menus
        # annoying side effect: new menus (for eg, via autoload) will go to the bottom and mess up the order
        vim.command("try | aunmenu %(root)s.⁣⁣buffer | catch /E329/ | endtry" % locals())

        # attach the vim menus (and recover gracefully)
        [vim.command("try | %(menu_command)s | catch // | echomsg '%(WARNING_MSG)s' | endtry" % locals())
                for menu_command in self.menus]

    def do_debug(self):
        """Attach the debug menu and write the log file."""

        import tempfile, platform

        LOGNAME_PREFIX = "headlights_"
        LOGNAME_SUFFIX = ".log"

        log_file = tempfile.NamedTemporaryFile(prefix=LOGNAME_PREFIX, suffix=LOGNAME_SUFFIX, delete=False)

        self.gen_debug_menu(log_file.name)

        date = time.ctime()
        platform = platform.platform()
        errors = "\n".join(self.errors)
        scriptnames = "\n".join(self.scriptnames)
        categories = "\n\n".join("%s:%s" % (key.upper(), self.categories[key]) for key in iter(self.categories.keys()))
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
