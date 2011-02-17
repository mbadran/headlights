#!/usr/bin/python
# encoding: utf-8

'''

Python helper script for headlights.vim. See README.mkd for details.

'''

import os, re, platform, time, tempfile

class Headlights:
    scripts = {}
    menus = []

    is_source_line = lambda self, x: re.match("^.*Last set from", x)

    # TODO: test if this is necessary
    sanitise_menu = lambda self, x: x.replace(" ", "\\ ").replace(".", "\\.").replace("|", "\\|").replace("<", "\\<")

    MODE_MAP = {
        "*": "Normal, Visual, Select, Operator-pending",
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

    DEFAULT_SPILLOVER = "*."
    TRUNC_LIMIT = 30
    NEW_LINE = os.linesep
    LOGNAME_PREFIX = "headlights_"
    LOGNAME_SUFFIX = ".log"

    def __init__(self, root, spillover, threshhold, debug, timer_start):
        # initialise script settings
        self.root = root
        self.spillover = spillover
        self.threshhold = threshhold
        self.debug = debug
        self.timer_start = timer_start

    def init_script(self, path):
        name = os.path.splitext(os.path.basename(path))[0]
        self.scripts[path] = {"name": name, "commands": [], "mappings": [], "abbreviations": [], "functions": [], "autocmds": []}

        return self.scripts[path]

    def get_spillover(self, name):
        # TODO: make sure that vim.vim plugins show up here (seems to load erratically)
        # for some reason, 'vimrc' pattern matching fails with $ at the end
        regexes = {r"^g?vimrc": "vim.", r"^\d": "0-9.", r"^[a-i]": "a-i.", r"^[j-r]": "j-r.", r"^[s-z]": "s-z."}

        for regex in regexes.keys():
            if re.match(regex, name.strip(), re.IGNORECASE):
                return regexes.get(regex)

        return DEFAULT_SPILLOVER

    def sanitise_path(self, path):
        # TODO: test if this is actually necessary
        path = re.sub(r"^~", os.getenv("HOME"), path)

        path = os.path.normpath(path)
        path = os.path.normcase(path)
        path = os.path.realpath(path)
        path = os.path.abspath(path)

        return path

    # add root menu
    def gen_menus(self):
        menu_head = self.root + "."

        for path, properties in self.scripts.items():
            name = self.sanitise_menu(properties["name"])

            if self.spillover and len(self.scripts.keys()) > self.threshhold:
                self.menu_script_prefix = menu_head + self.get_spillover(name) + name + "."
            else:
                self.menu_script_prefix = menu_head + name + "."

            self.menu_prefix = "amenu " + self.menu_script_prefix

            self.gen_commands_menu(properties["commands"], path)
            self.gen_files_menu(path)
            self.gen_mappings_menu(properties["mappings"])
            # disabled until performance optimisation
            #self.gen_autocmds_menu(properties["autocmds"])
            #self.gen_functions_menu(properties["functions"])
            self.gen_abbreviations_menu(properties["abbreviations"])
            self.gen_help_menu(name)

        self.menus.sort()

        if self.debug:
            for menu in self.menus:
                self.log_file.write("%s%c" % (menu, NEW_LINE))

    # add command menus
    def gen_commands_menu(self, commands, path):
        sep_priority = "...30"
        title_priority = "...40"
        item_priority = "...50"

        item_prefix = "amenu %s %s" % (item_priority, self.menu_script_prefix)

        if len(commands) > 0:
            sep_item = "amenu %s %s-Sep1- :<cr>" % (sep_priority, self.menu_script_prefix)
            self.menus.append(sep_item)

            title_item = "amenu %s %sCommands :<cr>" % (title_priority, self.menu_script_prefix)
            self.menus.append(title_item)
            title_item = "amenu disable %sCommands" % self.menu_script_prefix
            self.menus.append(title_item)

        for command in commands:
            command_name = self.sanitise_menu(command.keys()[0]).replace("\\ ", " ")      # unescape spaces in commands
            command_label = self.sanitise_menu(command[command.keys()[0]])

            # associate related mappings
            mappings = self.scripts[path]["mappings"]
            for mapping in mappings:
                matches = re.findall("^:(.*)<cr>$", mapping[2], re.IGNORECASE)
                if matches and matches[0] == command.keys()[0]:
                    command_name += "\ (%s)" % mapping[1]

            command_item = item_prefix + command_name + "<Tab>:" + command_label + " :" + command_name + "<cr>"
            self.menus.append(command_item)

    # add file menus
    def gen_files_menu(self, path):
        sep_priority = "...90"
        title_priority = "...100"
        item_priority = "...110"

        item_prefix_1 = "amenu %s.10 %s" % (item_priority, self.menu_script_prefix)
        item_prefix_2 = "amenu %s.20 %s" % (item_priority, self.menu_script_prefix)
        item_prefix_3 = "amenu %s.30 %s" % (item_priority, self.menu_script_prefix)
        item_prefix_4 = "amenu %s.40 %s" % (item_priority, self.menu_script_prefix)
        sep_prefix = "amenu %s.50 %s" % (item_priority, self.menu_script_prefix)
        item_prefix_5 = "amenu %s.60 %s" % (item_priority, self.menu_script_prefix)
        item_prefix_6 = "amenu %s.70 %s" % (item_priority, self.menu_script_prefix)
        item_prefix_7 = "amenu %s.80 %s" % (item_priority, self.menu_script_prefix)
        item_prefix_8 = "amenu %s.90 %s" % (item_priority, self.menu_script_prefix)
        item_prefix_9 = "amenu %s.100 %s" % (item_priority, self.menu_script_prefix)

        sep_item = "amenu %s %s-Sep3- :<cr>" % (sep_priority, self.menu_script_prefix)
        self.menus.append(sep_item)

        title_item = "amenu %s %sFiles :<cr>" % (title_priority, self.menu_script_prefix)
        self.menus.append(title_item)
        title_item = "amenu disable %sFiles" % self.menu_script_prefix
        self.menus.append(title_item)

        file_path = self.sanitise_menu(path)
        dir_path = self.sanitise_menu(os.path.dirname(path))
        trunc_file_path = "<" + file_path[-self.TRUNC_LIMIT:]

        path_item = item_prefix_1 + trunc_file_path + ".Edit\ here<Tab>:edit\ " + file_path + " :edit " + file_path + "<cr>"
        self.menus.append(path_item)

        path_item = item_prefix_2 + trunc_file_path + ".Edit\ in\ horizontal\ split<Tab>:split\ " + file_path + " :split " + file_path + "<cr>"
        self.menus.append(path_item)

        path_item = item_prefix_3 + trunc_file_path + ".Edit\ in\ vertical\ split<Tab>:vsplit\ " + file_path + " :vsplit " + file_path + "<cr>"
        self.menus.append(path_item)

        path_item = item_prefix_4 + trunc_file_path + ".Edit\ in\ new\ tab<Tab>:tabnew\ " + file_path + " :tabnew " + file_path + "<cr>"
        self.menus.append(path_item)

        sep_item = item_prefix_5 + trunc_file_path + ".-Sep1- :<cr>"
        self.menus.append(sep_item)

        # the only supported platforms are Unix and variants (by default) and Windows
        if (str.lower(platform.system()).startswith("Win")):
            path_item = item_prefix_6 + trunc_file_path + ".Explore\ in\ system\ browser<Tab>:silent\ !start\ explorer\ " + dir_path + " :silent !start " + dir_path + "<cr>"
        else:
            path_item = item_prefix_6 + trunc_file_path + ".Explore\ in\ system\ browser<Tab>:silent\ !open\ " + dir_path + " :silent !open " + dir_path + "<cr>"
        self.menus.append(path_item)

        #path_item = item_prefix + trunc_file_path + ".Explore\ in\ horizontal\ split<Tab>:Explore\ " + dir_path + " :Explore " + dir_path + "<cr>"
        #self.menus.append(path_item)

        #path_item = item_prefix + trunc_file_path + ".Explore\ in\ vertical\ split<Tab>:Explore!\ " + dir_path + " :Explore! " + dir_path + "<cr>"
        #self.menus.append(path_item)

        # unescape periods
        path_item = item_prefix_7 + trunc_file_path + ".Explore\ in\ horizontal\ split<Tab>:Sexplore\ " + dir_path + " :Sexplore " + dir_path.replace("\\.", ".") + "<cr>"
        self.menus.append(path_item)

        # unescape periods
        path_item = item_prefix_8 + trunc_file_path + ".Explore\ in\ vertical\ split<Tab>:Sexplore!\ " + dir_path + " :Sexplore! " + dir_path + "<cr>"
        self.menus.append(path_item)

        #path_item = item_prefix + trunc_file_path + ".Explore\ belowright<Tab>:Hexplore\ " + dir_path + " :Hexplore " + dir_path + "<cr>"
        #self.menus.append(path_item)

        #path_item = item_prefix + trunc_file_path + ".Explore\ aboveleft<Tab>:Hexplore!\ " + dir_path + " :Hexplore! " + dir_path + "<cr>"
        #self.menus.append(path_item)

        #path_item = item_prefix + trunc_file_path + ".Explore\ leftabove<Tab>:Vexplore\ " + dir_path + " :Vexplore " + dir_path + "<cr>"
        #self.menus.append(path_item)

        #path_item = item_prefix + trunc_file_path + ".Explore\ rightbelow<Tab>:Vexplore!\ " + dir_path + " :Vexplore! " + dir_path + "<cr>"
        #self.menus.append(path_item)

        #path_item = item_prefix + trunc_file_path + ".Explore\ in\ new\ tab<Tab>:Texplore\ " + dir_path + " :Texplore " + dir_path + "<cr>"
        #self.menus.append(path_item)

        path_item = item_prefix_9 + trunc_file_path + ".Explore\ in\ NERDTree<Tab>:NERDTreeFind\ " + dir_path + " :NERDTree " + dir_path + "<cr>"
        self.menus.append(path_item)

    # add mapping menus
    def gen_mappings_menu(self, mappings):
        sep_priority = "...60"
        title_priority = "...70"
        item_priority = "...80"

        item_prefix = "amenu %s %s" % (item_priority, self.menu_script_prefix)

        if len(mappings) > 0:
            sep_item = "amenu %s %s-Sep2- :<cr>" % (sep_priority, self.menu_script_prefix)
            self.menus.append(sep_item)

            title_item = "amenu %s %sMappings :<cr>" % (title_priority, self.menu_script_prefix)
            self.menus.append(title_item)
            title_item = "amenu disable %sMappings" % self.menu_script_prefix
            self.menus.append(title_item)

        for mode, keys, command in mappings:
            mode = self.sanitise_menu(mode)
            keys = self.sanitise_menu(keys)
            command = self.sanitise_menu(command)

            mapping_item = item_prefix + mode + "." + keys + "<Tab>" + command + " :" + "<cr>"

            self.menus.append(mapping_item)

    # add autocmd menus
    def gen_autocmds_menu(self, autocmds):
        sep_priority = "...150"
        title_priority = "...160"
        item_priority = "...170"

        item_prefix = "amenu %s %s" % (item_priority, self.menu_script_prefix)

        if len(autocmds) > 0:
            sep_item = "amenu %s %s-Sep5- :<cr>" % (sep_priority, self.menu_script_prefix)
            self.menus.append(sep_item)

            title_item = "amenu %s %sAutocmds :<cr>" % (title_priority, self.menu_script_prefix)
            self.menus.append(title_item)
            title_item = "amenu disable %sAutocmds" % self.menu_script_prefix
            self.menus.append(title_item)

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

            autocmd_item += trunc_autocmd + "<Tab>" + autocmd + " :" + "<cr>"

            self.menus.append(autocmd_item)

    # add function menus
    def gen_functions_menu(self, functions):
        sep_priority = "...180"
        item_priority = "...190"

        item_prefix = "amenu %s %s" % (item_priority, self.menu_script_prefix)

        if len(functions) > 0:
            sep_item = "amenu %s %s-Sep6- :<cr>" % (sep_priority, self.menu_script_prefix)
            self.menus.append(sep_item)

        for function in functions:
            function = trunc_function = self.sanitise_menu(function)

            if (len(function) > self.TRUNC_LIMIT):
                trunc_function = function[:self.TRUNC_LIMIT] + ">"

            function_item = item_prefix + "Functions." + trunc_function + "<Tab>" + function + " :" + "<cr>"

            self.menus.append(function_item)

    # add abbreviation menus
    # TODO: test expressions
    def gen_abbreviations_menu(self, abbreviations):
        sep_priority = "...120"
        title_priority = "...130"
        item_priority = "...140"

        item_prefix = "amenu %s %s" % (item_priority, self.menu_script_prefix)

        if len(abbreviations) > 0:
            sep_item = "amenu %s %s-Sep4- :<cr>" % (sep_priority, self.menu_script_prefix)
            self.menus.append(sep_item)

            title_item = "amenu %s %sAbbreviations :<cr>" % (title_priority, self.menu_script_prefix)
            self.menus.append(title_item)
            title_item = "amenu disable %sAbbreviations" % self.menu_script_prefix
            self.menus.append(title_item)

        for mode, expression, lhs, rhs in abbreviations:
            lhs = trunc_lhs = self.sanitise_menu(lhs)
            mode = self.sanitise_menu(mode)

            if (len(lhs) > self.TRUNC_LIMIT):
                trunc_lhs = lhs[:self.TRUNC_LIMIT] + ">"

            if not expression:
                expression = ""

            #if expression:
                #expression = "<expr>: "
            #else:
                #expression = ""

            abbreviation_item = item_prefix + mode + "." + trunc_lhs + "<Tab>" + expression + rhs + " :" + "<cr>"

            self.menus.append(abbreviation_item)

    # add help menus
    def gen_help_menu(self, name):
        priority = "...10"
        sep_priority = "...20"

        prefix = "amenu %s %s" % (priority, self.menu_script_prefix)

        #path_item = self.menu_prefix + "Help" + " :helpgrep " + name + "<cr>"
        path_item = prefix + "Help" + " :help " + name + "<cr>"
        self.menus.append(path_item)

        #sep_item = "amenu %s %s-Sep1- :<cr>" % (sep_priority, self.menu_script_prefix)
        #self.menus.append(sep_item)

    def get_source_script(self, line):
        source_path = re.findall(r"^.*Last set from (.+$)", line)[0]
        source_path = self.sanitise_path(source_path)

        # TODO: this condition shouldn't occur...test
        #script = scripts.get(source_path, init_script(source_path))
        if source_path in self.scripts:
            return self.scripts.get(source_path)
        else:
            #print("############# no existing script found for this source!")
            return self.init_script(source_path)

    def parse_scriptnames(self, scriptnames):
        for path in scriptnames:
            path = re.sub(r"^\s*\d+:\s+", "", path)     # strip out leading indexes
            path = self.sanitise_path(path)

            self.init_script(path)

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

                #try:
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

                # set blank modes to * (these were originally spaces, but were stripped)
                if mode is "":
                    mode = "*"

                # delete anything preceding the first :
                # TODO: test that this works
                command = re.sub("^.*:", ":", command)

                # cater for multiple modes
                modes = list(mode)

                # append mode descriptions
                #modes = [m + " - " + self.MODE_MAP.get(m) for m in modes]
                modes = ["%s - %s" % (m, self.MODE_MAP.get(m)) for m in modes]

                # get the source script from the next list item
                try:
                    source_script = self.get_source_script(mappings[i+1])

                    # add the mapping to the source script
                    for m in modes:
                        source_script["mappings"].append([m, keys, command])

                # handle mappings that don't have a source
                except IndexError:
                    pass

    # TODO: this is quite broken. dodgy, slow algorithm. misses some autocmds. botches some patterns. fix.
    def parse_autocmds(self, autocmds):
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

    def parse_functions(self, functions):
        for i, line in enumerate(functions):
            if not self.is_source_line(line):
                function = line.split("function ")[1]

                # get the source script from the next list item
                source_script = self.get_source_script(functions[i+1])

                # add the function to the source script
                source_script["functions"].append(function)

    # TODO: test <expr> abbreviations
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

                # append mode descriptions
                #modes = [m + " - " + self.MODE_MAP.get(m) for m in modes]
                modes = ["%s - %s" % (m, self.MODE_MAP.get(m)) for m in modes]

                # get the source script from the next list item
                source_script = self.get_source_script(abbreviations[i+1])

                # add the mapping to the source script
                for m in modes:
                    source_script["abbreviations"].append([m, expression, lhs, rhs])

    def get_menu_commands(self, scriptnames, **components):
        log_file = None
        log_name = None

        if self.debug:
            self.log_file = tempfile.NamedTemporaryFile(prefix=LOGNAME_PREFIX, suffix=LOGNAME_SUFFIX, delete=False)
            log_name = self.log_file.name
            self.log_file.write("Headlights (Vim) log, %s.%c%c" % (time.ctime(), NEW_LINE, NEW_LINE))

        self.parse_scriptnames(scriptnames.strip().split("\n"))

        for key in components.keys():
            if components[key] is not "":
                function = getattr(self, "parse_" + key)
                function(components[key].strip().split("\n"))

        self.gen_menus()

        if self.debug:
            timer_elapsed = time.time() - timer_start
            self.log_file.write("%cHeadlights python code executed in %.2f seconds" % (NEW_LINE, timer_elapsed))
            self.log_file.close()

        return log_name, self.menus
