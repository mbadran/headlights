#!/usr/bin/python
# encoding: utf-8

'''

Python helper script to generate menus for headlights.vim. See README.mkd for details.

'''

import os, re, platform, time, tempfile

class Headlights:
    plugins = {}
    menus = []

    is_source_line = lambda self, line: re.match("^.*Last set from", line)

    sanitise_menu = lambda self, menu: menu.replace("\\", "\\\\").replace(" ", "\\ ").replace(".", "\\.").replace("|", "\\|").replace("<", "\\<")

    # modes and their descriptions
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

    # the limit after which a menu item is truncated
    TRUNC_LIMIT = 30

    # initialises default settings
    def __init__(self, root, spillover, threshhold, topseparator, debug, vim_timer):
        self.root = root
        self.spillover = int(spillover)
        self.threshhold = int(threshhold)
        self.topseparator = bool(int(topseparator))
        self.debug = bool(int(debug))
        self.vim_timer = float(vim_timer)
        self.python_timer = time.time()

    # initialises new plugins (aka scripts/bundles)
    def init_plugin(self, path):
        name = os.path.splitext(os.path.basename(path))[0]
        self.plugins[path] = {"name": name, "commands": [], "mappings": [], "abbreviations": [], "functions": [], "autocmds": []}

        return self.plugins[path]

    # returns the appropriate menu label
    def get_spillover(self, name, path):
        spillover = "*."

        if re.match(r".*\/runtime\/.*", path, re.IGNORECASE):
            # use an invisible separator (looks like a space) to move the menu to the bottom
            spillover = "⁣runtime"
        else:
            regexes = {r"^g?vimrc": "⁣vimrc", r"^\d": "0 - 9", r"^[a-i]": "a - i", r"^[j-r]": "j - r", r"^[s-z]": "s - z"}

            for regex in regexes.keys():
                if re.match(regex, name.strip(), re.IGNORECASE):
                    spillover = regexes.get(regex)
                    break

        return self.sanitise_menu(spillover) + "."

    # sanitises a path so it can be accessed by vim
    def sanitise_path(self, path):
        path = re.sub(r"^~", os.getenv("HOME"), path)

        path = os.path.normpath(path)
        path = os.path.normcase(path)
        path = os.path.realpath(path)
        path = os.path.abspath(path)

        return path

    # adds the root menu and coordinates menu categories
    def gen_menus(self):
        menu_head = self.root + "."

        if self.topseparator:
            topsep_priority = "100"
            topsep_item = "amenu %s %s-Sep0- :" % (topsep_priority, menu_head)
            self.menus.append(topsep_item)

        for path, properties in self.plugins.items():
            name = self.sanitise_menu(properties["name"])

            if self.spillover and len(self.plugins.keys()) > self.threshhold:
                self.menu_script_prefix = menu_head + self.get_spillover(name, path) + name + "."
            else:
                self.menu_script_prefix = menu_head + name + "."

            # the help menu needs to be first so sorted() can get the script order right
            self.gen_help_menu(name)
            self.gen_commands_menu(properties["commands"], path)
            self.gen_mappings_menu(properties["mappings"])
            self.gen_files_menu(path)
            self.gen_abbreviations_menu(properties["abbreviations"])
            #disabled until autocmds are fixed
            #self.gen_autocmds_menu(properties["autocmds"])
            self.gen_functions_menu(properties["functions"])

    # adds command menus
    def gen_commands_menu(self, commands, path):
        if len(commands) > 0:
            sep_priority = "130"
            title_priority = "140"
            item_priority = "150"

            sep_item = "amenu %s %s-Sep1- :" % (sep_priority, self.menu_script_prefix)
            self.menus.append(sep_item)

            title_item = "amenu %s %sCommands :" % (title_priority, self.menu_script_prefix)
            self.menus.append(title_item)
            disabled_item = "amenu disable %sCommands" % self.menu_script_prefix
            self.menus.append(disabled_item)

            for command in commands:
                # unescape spaces in commands
                command_name = self.sanitise_menu(command.keys()[0]).replace("\\ ", " ")
                command_label = self.sanitise_menu(command[command.keys()[0]])

                # associate related mappings
                mappings = self.plugins[path]["mappings"]
                for mapping in mappings:
                    matches = re.findall("^:(.*)<cr>$", mapping[2], re.IGNORECASE)
                    if matches and matches[0] == command.keys()[0]:
                        command_name += "\ (%s)" % mapping[1]

                command_item = "amenu %s %s%s<Tab>:%s :%s<cr>" % (item_priority, self.menu_script_prefix, command_name, command_label, command_name)
                self.menus.append(command_item)

    # adds file menus
    # TODO: improve this. some files via :scriptnames aren't showing up. also, consider adding another piece of metatada: (script) parent -- if a script's parent is the beginning of another bundle's parent, then the first script should be included in the second's menu.
    def gen_files_menu(self, path):
        sep_priority = "190"
        title_priority = "200"
        item_priority = "210"

        sep_item = "amenu %s %s-Sep3- :" % (sep_priority, self.menu_script_prefix)
        self.menus.append(sep_item)

        title_item = "amenu %s %sFiles :" % (title_priority, self.menu_script_prefix)
        self.menus.append(title_item)
        disabled_item = "amenu disable %sFiles" % self.menu_script_prefix
        self.menus.append(disabled_item)

        file_path = self.sanitise_menu(path)
        dir_path = self.sanitise_menu(os.path.dirname(path))
        trunc_file_path = "<" + file_path[-self.TRUNC_LIMIT:]

        # make the file appear in the "File > Open Recent" menu
        # also, honour the "Open files from applications" setting
        if platform.system() == "Darwin":
            open_cmd = "silent !open -a MacVim"
            reveal_cmd = "silent !open"
        elif platform.system() == "Windows":
            open_cmd = "silent !start gvim.exe"
            reveal_cmd = "silent !start"
        # TODO: handle linux
        else:
            open_cmd = "edit"
            reveal_cmd = ""

        open_item = "amenu %s.10 %s%s.Open\ File<Tab>%s :%s %s<cr>" % (item_priority, self.menu_script_prefix, trunc_file_path, file_path, open_cmd, file_path)
        self.menus.append(open_item)

        # unescape full stops
        explore_item = "amenu %s.20 %s%s.Explore\ in\ Vim<Tab>%s :Explore %s<cr>" % (item_priority, self.menu_script_prefix, trunc_file_path, dir_path, dir_path.replace("\\.", "."))
        self.menus.append(explore_item)

        if reveal_cmd:
            reveal_item = "amenu %s.30 %s%s.Explore\ in\ System<Tab>%s :%s %s<cr>" % (item_priority, self.menu_script_prefix, trunc_file_path, dir_path, reveal_cmd, dir_path)
            self.menus.append(reveal_item)

    # adds mapping menus
    def gen_mappings_menu(self, mappings):
        if len(mappings) > 0:
            sep_priority = "160"
            title_priority = "170"
            item_priority = "180"

            sep_item = "amenu %s %s-Sep2- :" % (sep_priority, self.menu_script_prefix)
            self.menus.append(sep_item)

            title_item = "amenu %s %sMappings :" % (title_priority, self.menu_script_prefix)
            self.menus.append(title_item)
            disabled_item = "amenu disable %sMappings" % self.menu_script_prefix
            self.menus.append(disabled_item)

            for mode, keys, command in mappings:
                mode = self.sanitise_menu(mode)
                keys = self.sanitise_menu(keys)
                command = self.sanitise_menu(command)

                mapping_item = "amenu %s %s%s.%s<Tab>%s :<cr>" % (item_priority, self.menu_script_prefix, mode, keys, command)
                self.menus.append(mapping_item)
                disabled_item = "amenu disable %s%s.%s" % (self.menu_script_prefix, mode, keys)
                self.menus.append(disabled_item)

    # adds autocmd menus
    def gen_autocmds_menu(self, autocmds):
        if len(autocmds) > 0:
            sep_priority = "250"
            title_priority = "260"
            item_priority = "270"

            sep_item = "amenu %s %s-Sep5- :" % (sep_priority, self.menu_script_prefix)
            self.menus.append(sep_item)

            # TODO: remove item_prefix as in the other menu categories
            item_prefix = "amenu %s %s" % (item_priority, self.menu_script_prefix)

            title_item = "amenu %s %sAutocmds :" % (title_priority, self.menu_script_prefix)
            self.menus.append(title_item)
            disabled_item = "amenu disable %sAutocmds" % self.menu_script_prefix
            self.menus.append(disabled_item)

            for buffer, group, event, pattern, autocmd in autocmds:
                autocmd = trunc_autocmd = self.sanitise_menu(autocmd)

                if (len(autocmd) > self.TRUNC_LIMIT):
                    trunc_autocmd = autocmd[:self.TRUNC_LIMIT] + ">"

                autocmd_item = item_prefix

                if buffer:
                    autocmd_item += self.sanitise_menu(buffer) + "."

                if group:
                    autocmd_item += self.sanitise_menu(group) + "."

                autocmd_item += self.sanitise_menu(event) + "."

                if pattern:
                    autocmd_item += self.sanitise_menu(pattern) + "."

                item_prefix = "amenu %s %s" % (item_priority, self.menu_script_prefix)
                autocmd_item += trunc_autocmd + "<Tab>" + autocmd + " :" + "<cr>"

                self.menus.append(autocmd_item)

    # adds function menus
    def gen_functions_menu(self, functions):
        if len(functions) > 0:
            sep_priority = "280"
            item_priority = "290"

            sep_item = "amenu %s %s-Sep6- :" % (sep_priority, self.menu_script_prefix)
            self.menus.append(sep_item)

            for function in functions:
                function = trunc_function = self.sanitise_menu(function)

                # only show a label if the function name is truncated
                if (len(function) > self.TRUNC_LIMIT):
                    trunc_function = function[:self.TRUNC_LIMIT] + ">"
                else:
                    function = ""

                function_item = "amenu %s %sFunctions.%s<Tab>%s :<cr>" % (item_priority, self.menu_script_prefix, trunc_function, function)
                self.menus.append(function_item)
                disabled_item = "amenu disable %sFunctions.%s" % (self.menu_script_prefix, trunc_function)
                self.menus.append(disabled_item)

    # adds abbreviation menus
    def gen_abbreviations_menu(self, abbreviations):
        if len(abbreviations) > 0:
            sep_priority = "220"
            title_priority = "230"
            item_priority = "240"

            sep_item = "amenu %s %s-Sep4- :" % (sep_priority, self.menu_script_prefix)
            self.menus.append(sep_item)

            title_item = "amenu %s %sAbbreviations :" % (title_priority, self.menu_script_prefix)
            self.menus.append(title_item)
            disabled_item = "amenu disable %sAbbreviations" % self.menu_script_prefix
            self.menus.append(disabled_item)

            for mode, expression, lhs, rhs in abbreviations:
                lhs = trunc_lhs = self.sanitise_menu(lhs)
                mode = self.sanitise_menu(mode)

                if (len(lhs) > self.TRUNC_LIMIT):
                    trunc_lhs = lhs[:self.TRUNC_LIMIT] + ">"

                if not expression:
                    expression = ""

                # TODO: test expressions
                #if expression:
                    #expression = "<expr>: "
                #else:
                    #expression = ""

                abbr_item = "amenu %s %s%s.%s<Tab>%s%s :<cr>" % (item_priority, self.menu_script_prefix, mode, trunc_lhs, expression, rhs)
                self.menus.append(abbr_item)
                disabled_item = "amenu disable %s%s.%s" % (self.menu_script_prefix, mode, trunc_lhs)
                self.menus.append(disabled_item)

    # adds help menus
    def gen_help_menu(self, name):
        title_priority = "110"
        help_priority = "120"

        title_item = "amenu %s %sHelp :" % (title_priority, self.menu_script_prefix)
        self.menus.append(title_item)
        disabled_item = "amenu disable %sHelp" % self.menu_script_prefix
        self.menus.append(disabled_item)

        help_item = "amenu %s %sDoc<Tab>help\ %s :help %s<cr>" % (help_priority, self.menu_script_prefix, name, name)
        self.menus.append(help_item)

        help_item = "amenu %s %sOccurrences<Tab>helpgrep\ %s :exec 'helpgrep %s' \| copen<cr>" % (help_priority, self.menu_script_prefix, name, name)
        self.menus.append(help_item)

    # adds debug menus
    def gen_debug_menu(self, log_name):
        sep_priority = "300"
        open_priority = "310"
        sexplore_priority = "320"
        explore_priority = "330"

        sep_item = "amenu %s %s.-SepX- :" % (sep_priority, self.root)
        self.menus.append(sep_item)

        if platform.system() == "Darwin":
            open_log_cmd = "silent !open -a MacVim"
            reveal_log_cmd = "silent !open"
        elif platform.system() == "Windows":
            open_log_cmd = "silent !start gvim.exe"
            reveal_log_cmd = "silent !start"
        else:
            open_log_cmd = "edit"
            reveal_log_cmd = ""

        debug_item = "amenu %s %s.debug.Open\ Log<Tab>%s :%s %s<cr>" % (open_priority, self.root, self.sanitise_menu(log_name), open_log_cmd, log_name)
        self.menus.append(debug_item)

        debug_item = "amenu %s %s.debug.Explore\ in\ Vim<Tab>%s :Explore %s<cr>" % (sexplore_priority, self.root, os.path.dirname(log_name), os.path.dirname(log_name))
        self.menus.append(debug_item)

        if reveal_log_cmd:
            debug_item = "amenu %s %s.debug.Explore\ in\ System<Tab>%s :%s %s<cr>" % (explore_priority, self.root, os.path.dirname(log_name), reveal_log_cmd, os.path.dirname(log_name))
            self.menus.append(debug_item)

    # extracts the source path from the line
    def get_source_script(self, line):
        source_path = re.findall(r"^.*Last set from (.+$)", line)[0]
        source_path = self.sanitise_path(source_path)

        return self.plugins.get(source_path)

    # extracts the scripts (aka plugins/bundles)
    def parse_scriptnames(self, scriptnames):
        for path in scriptnames:
            # strip out leading indexes
            path = re.sub(r"^\s*\d+:\s+", "", path)
            path = self.sanitise_path(path)

            self.init_plugin(path)

    # extracts the commands
    # TODO: consider that some commands are local to the buffer, see how you'd handle reloading
    def parse_commands(self, commands):
        # delete the listing header
        commands = commands[1:]

        for i, line in enumerate(commands):
            line = line.strip()

            # begin with command lines
            if not self.is_source_line(line):
                regex = r'''
                ^
                ([!"b]\s+)?                 # attribute
                (\w+\s+)                    # command
                ([01+?*]\s+)?               # args
                ((\.|1c|%|0c)\s+)?          # range
                ((dir|file|buffer)\s+)?     # complete
                :?                          # potential colon
                ([a-z].+)                   # definition/label
                $
                '''

                matches = re.findall(regex, line, re.VERBOSE | re.IGNORECASE)

                attribute, command, args, range, complete, label = \
                    matches[0][0].strip(), \
                    matches[0][1].strip(), \
                    matches[0][2].strip(), \
                    matches[0][3].strip(), \
                    matches[0][5].strip(), \
                    matches[0][7].strip()

                # get the source script from the next list item
                source_script = self.get_source_script(commands[i+1])

                source_script["commands"].append({command: label})

    # extracts the mappings
    def parse_mappings(self, mappings):
        for i, line in enumerate(mappings):
            # begin with mapping lines
            if not self.is_source_line(line):
                regex = r'''
                ^
                ([nvsxo!ilc]+)?    # mode
                \s+
                ([\S]+)            # keys
                \s+
                ([*&@]+)?          # attribute
                \s*
                (.+)               # command
                $
                '''

                matches = re.findall(regex, line, re.VERBOSE | re.IGNORECASE)

                # TODO: consider doing something with the attribute
                # TODO: this whole thing is complicated because there can be more than
                # one mode for the same mapping.
                # ISSUE: mappings with multiple modes in a mapping (eg. searchcomplete /) come through with
                # a space value instead, so they appear as "Normal, Visual, Select, and Operator-pending", when in fact,
                # they aren't.
                mode, keys, attribute, command = \
                    matches[0][0].strip(), \
                    matches[0][1].strip(), \
                    matches[0][2].strip(), \
                    matches[0][3].strip()

                # restore blank mode to original value (space)
                if mode is "":
                    mode = " "

                # delete anything preceding the first :
                # TODO: test that this works
                command = re.sub("^.*:", ":", command)

                # cater for multiple modes
                modes = list(mode)

                # translate to mode descriptions
                modes = [self.MODE_MAP.get(m) for m in modes]

                # get the source script from the next list item
                try:
                    source_script = self.get_source_script(mappings[i+1])

                    # add the mapping to the source script
                    for m in modes:
                        source_script["mappings"].append([m, keys, command])

                # handle mappings that don't have a source
                except IndexError:
                    pass

    # extracts the autocmds
    # TODO: this is quite broken. incredibly slow. duplicates items. misses some autocmds. botches some patterns. fix.
    def parse_autocmds(self, autocmds):
        # disabled until autocmds are fixed
        return

        # delete the listing header
        autocmds = autocmds[1:]

        # group/event lines have no leading spaces
        is_event_line = lambda x: not re.match("^\s", x)
        is_buffer_line = lambda x: re.match("^\s*__", x)

        pos = 0
        for i in enumerate(autocmds):
            if pos > i:
                continue

            # start with group/event lines
            if is_event_line(autocmds[pos]):
                group = None

                try:
                    group, event = autocmds[pos].strip().split()
                except:
                    event = autocmds[pos]

                pos += 1
                while pos < len(autocmds):
                    if is_event_line(autocmds[pos]):
                        # we're done with this group/event, continue through
                        break
                    else:
                        buffer = None
                        group = None

                        if is_buffer_line(autocmds[pos]):
                            buffer = autocmds[pos].strip()
                            pos =+ 1      # move to the next line

                        # handle cases where the source is the next line
                        if self.is_source_line(autocmds[pos+1]):
                            regex = r'''
                            ^
                            \s{4}
                            ([^\s]+)    # pattern
                            \s+
                            (.+)        # autocmd
                            $
                            '''

                            try:
                                pattern, autocmd = re.findall(regex, autocmds[pos])[0]

                            # handle autocmds with no pattern (defaults to pattern from previous autocmd)
                            except IndexError:
                                pattern = "$"
                                autocmd = autocmds[pos]

                            source = autocmds[pos+1]
                            pos += 2

                        # handle cases where the source is further down
                        else:
                            pattern = autocmds[pos]
                            autocmd = autocmds[pos+1]
                            source = autocmds[pos+2]
                            pos += 3

                        # get the source script
                        source_script = self.get_source_script(source)
                        source_script["autocmds"].append([buffer, group, event.strip(), pattern.strip(), autocmd.strip()])

# extracts the functions
    def parse_functions(self, functions):
        for i, line in enumerate(functions):
            if not self.is_source_line(line):
                function = line.split("function ")[1]

                # get the source script from the next list item
                source_script = self.get_source_script(functions[i+1])

                # add the function to the source script
                source_script["functions"].append(function)

    # TODO: test <expr> abbreviations
    # extracts the abbreviations
    def parse_abbreviations(self, abbreviations):
        for i, line in enumerate(abbreviations):
            # begin with mapping lines
            if not self.is_source_line(line):
                regex = r'''
                ^
                ([nvsxo!ilc]+)?    # mode
                \s+
                (<expr>)?          # expression
                \s+
                ([\S]+)            # lhs
                \s+
                (.+)               # rhs
                $
                '''

                matches = re.findall(regex, line, re.VERBOSE | re.IGNORECASE)

                try:
                    mode, expression, lhs, rhs = \
                        matches[0][0].strip(), \
                        matches[0][1].strip(), \
                        matches[0][2].strip(), \
                        matches[0][3].strip()
                except IndexError:
                    #print("error", mode, expression, lhs, rhs)
                    pass

                # restore blank mode to original value (space)
                if mode is "":
                    mode = " "

                # delete anything preceding the first :
                # TODO: test that this works
                #command = re.sub("^.*:", ":", command)

                # cater for multiple modes
                # TODO: test that this works (issue here)
                # ISSUE: mappings with multiple modes in a mapping (eg. searchcomplete /) come through with
                # a space value instead, so they appear as "Normal, Visual, Select, and Operator-pending", when in fact,
                # they aren't.
                modes = list(mode)

                # translate to mode descriptions
                modes = [self.MODE_MAP.get(m) for m in modes]

                # get the source script from the next list item
                source_script = self.get_source_script(abbreviations[i+1])

                # add the mapping to the source script
                for m in modes:
                    source_script["abbreviations"].append([m, expression, lhs, rhs])

    # attaches the debug menu and writes the log file
    def do_debug(self, scriptnames, **categories):
        LOGNAME_PREFIX = "headlights_"
        LOGNAME_SUFFIX = ".log"

        log_file = tempfile.NamedTemporaryFile(prefix=LOGNAME_PREFIX, suffix=LOGNAME_SUFFIX, delete=False)

        self.gen_debug_menu(log_file.name)

        log_file.write("Headlights (Vim) log, %s%c" % (time.ctime(), os.linesep))
        log_file.write("Platform: %s%s" % (platform.platform(), os.linesep * 2))
        log_file.write("Plugins:%s%s" % (scriptnames, os.linesep * 2))
        [log_file.write("%s:%s%s" % (key.upper(), categories[key], os.linesep * 2)) for key in categories.keys()]
        [log_file.write("%s%c" % (menu, os.linesep)) for menu in self.menus]
        log_file.write("%cHeadlights vim code executed in %.2f seconds" % (os.linesep, self.python_timer - self.vim_timer))
        log_file.write("%cHeadlights python code executed in %.2f seconds" % (os.linesep, time.time() - self.python_timer))
        log_file.close()

    # coordinates the action and returns the vim menus
    def get_menu_commands(self, scriptnames, **categories):
        try:
            self.parse_scriptnames(scriptnames.strip().split("\n"))

            # parse the menu categories with the similarly named functions
            for key in categories.keys():
                if categories[key] is not "":
                    function = getattr(self, "parse_" + key)
                    function(categories[key].strip().split("\n"))

            self.gen_menus()

        except:
            # let the full strack trace reach vim
            raise

        finally:
            if self.debug:
                self.do_debug(scriptnames, **categories)

        return sorted(self.menus, key=lambda menu: menu.lower())
