#!/usr/bin/ruby -ws

$v ||= false

stack = []
last_token = nil
reduce_line = nil

def munge s
  renames = [
             "'='",             "tEQL",
             "'!'",             "tBANG",
             "'%'",             "tPERCENT",
             "'&'",             "tAMPER2",
             "'('",             "tLPAREN2",
             "')'",             "tRPAREN",
             "'*'",             "tSTAR2",
             "'+'",             "tPLUS",
             "','",             "tCOMMA",
             "'-'",             "tMINUS",
             "'.'",             "tDOT",
             "'/'",             "tDIVIDE",
             "';'",             "tSEMI",
             "':'",             "tCOLON",
             "'<'",             "tLT",
             "'>'",             "tGT",
             "'?'",             "tEH",
             "'['",             "tLBRACK",
             "'\\n'",           "tNL",
             "']'",             "tRBRACK",
             "'^'",             "tCARET",
             "'`'",             "tBACK_REF2",
             "'{'",             "tLCURLY",
             "'|'",             "tPIPE",
             "'}'",             "tRCURLY",
             "'~'",             "tTILDE",
             '"["',             "tLBRACK",

             # 2.0 changes?
             '"<=>"',            "tCMP",
             '"=="',             "tEQ",
             '"==="',            "tEQQ",
             '"!~"',             "tNMATCH",
             '"=~"',             "tMATCH",
             '">="',             "tGEQ",
             '"<="',             "tLEQ",
             '"!="',             "tNEQ",
             '"<<"',             "tLSHFT",
             '">>"',             "tRSHFT",
             '"*"',              "tSTAR",

             '".."',             "tDOT2",

             '"&"',              "tAMPER",
             '"&&"',             "tANDOP",
             '"&."',             "tLONELY",
             '"||"',             "tOROP",

             '"..."',            "tDOT3",
             '"**"',             "tPOW",
             '"unary+"',         "tUPLUS",
             '"unary-"',         "tUMINUS",
             '"[]"',             "tAREF",
             '"[]="',            "tASET",
             '"::"',             "tCOLON2",
             '"{ arg"',          "tLBRACE_ARG",
             '"( arg"',          "tLPAREN_ARG",
             '"("',              "tLPAREN",
             'rparen',           "tRPAREN",
             '"{"',              "tLBRACE",
             '"=>"',             "tASSOC",
             '"->"',             "tLAMBDA",
             '":: at EXPR_BEG"', "tCOLON3",
             '"**arg"',          "tDSTAR",
             '","',              "tCOMMA",

             # other

             'tLBRACK2',        "tLBRACK", # HACK

             "' '",             "tSPACE", # needs to be later to avoid bad hits

             "/* empty */",     "none",
             /^\s*$/,           "none",

             "keyword_BEGIN",   "klBEGIN",
             "keyword_END",     "klEND",
             /keyword_(\w+)/,   proc { "k#{$1.upcase}" },
             /\bk_([a-z_]+)/,   proc { "k#{$1.upcase}" },
             /modifier_(\w+)/,  proc { "k#{$1.upcase}_MOD" },
             "kVARIABLE",       "keyword_variable", # ugh

             # 2.6 collapses klBEGIN to kBEGIN
             "klBEGIN",   "kBEGIN",
             "klEND",     "kEND",

             /keyword_(\w+)/,          proc { "k#{$1.upcase}" },
             /\bk_([^_][a-z_]+)/,      proc { "k#{$1.upcase}" },
             /modifier_(\w+)/,         proc { "k#{$1.upcase}_MOD" },

             "kVARIABLE",       "keyword_variable", # ugh: this is a rule name

             # UGH
             "k_LINE__",       "k__LINE__",
             "k_FILE__",       "k__FILE__",
             "k_ENCODING__",   "k__ENCODING__",

             '"defined?"',     "kDEFINED",

             "<none>",         "none",

             '"do (for condition)"', "kDO_COND",
             '"do (for lambda)"',    "kDO_LAMBDA",
             '"do (for block)"',     "kDO_BLOCK",

             /\"(\w+) \(modifier\)\"/, proc { |x| "k#{$1.upcase}_MOD" },
             /\"(\w+)\"/,              proc { |x| "k#{$1.upcase}" },

             /@(\d+)(\s+|$)/,       "",
             /\$?@(\d+) */,         "", # TODO: remove?
            ]

  renames.each_slice(2) do |(a, b)|
    if Proc === b then
      s.gsub!(a, &b)
    else
      s.gsub!(a, b)
    end
  end

  s.strip.squeeze " "
end

ARGF.each_line do |line|
  case line
  when /^(Stack now|Entering state|Shifting|Cleanup|Starting)/ then
    # do nothing
  when /^vtable_/ then
    # do nothing
  when /Gem::MissingSpecError/ then
    # do nothing -- ruby 2.5 is being bitchy?
  when /^Reading a token: Next token is token (.*?) \(\)/ then
    token = munge $1
    next if last_token == token
    puts "next token is %p (%p)" % [token, last_token]
    last_token = token
  when /^Reading a token: / then
    next # skip
  when /^read\s+:(\w+)/ then # read    :tNL(tNL) nil
    token = munge $1
    next if last_token == token
    puts "next token is %p (%p)" % [token, last_token]
    last_token = token
  when /^Next token is token ("[^"]+"|\S+)/ then
    token = munge $1
    next if last_token == token
    puts "next token is %p (%p)" % [token, last_token]
    last_token = token
  when /^read\s+false/ then # read    false($end) "$end"
    puts "next token is EOF"
  when /^Now at end of input./ then
    # do nothing
  when /^.:scan=>\["([^"]+)"/ then
    puts "scan = %p" % [$1]
  when /^Reducing stack by rule (\d+) \(line (\d+)\):/ then
    reduce_line = $2.to_i
  when /^   \$\d+ = (?:token|nterm) (.+) \(.*\)/ then
    item = $1
    stack << munge(item)
  when /^-> \$\$ = (?:token|nterm) (.+) \(.*\)/ then
    stack << "none" if stack.empty?
    item = munge $1
    x = stack.map { |s| s.strip }.join " "
    if x != item then # prevent kdef -> kdef
      if $v && reduce_line then
        puts "reduce #{x} --> #{item} at #{reduce_line}".squeeze " "
      else
        puts "reduce #{x} --> #{item}".squeeze " "
      end
      puts
    end
    reduce_line = nil
    stack.clear
  when /^reduce/ then # ruby_parser side
    puts munge line.chomp
    puts
  when /^(\w+_stack)\.(\w+)/ then
    # TODO: make pretty, but still informative w/ line numbers etc
    puts line.gsub("true", "1").gsub("false", "0")
    # puts "#{$1}(#{$2})"
  when /^(\w+_stack(\(\w+\))?: \S+)/ then
    # _data = $v ? line.chomp : $1
    # puts line
    # TODO: make pretty, but still informative w/ line numbers etc
    puts line.gsub("true", "1").gsub("false", "0")
  when /^lex_state: :?([\w|]+) -> :?([\w|]+)(?: (?:at|from) (.*))?/ then
    if $3 && $v then
      puts "lex_state: #{$1.upcase} -> #{$2.upcase} at #{$3}"
    else
      puts "lex_state: #{$1.upcase} -> #{$2.upcase}"
    end
  when /debug|FUCK/ then
    puts line.chomp
  when /^(#.*parse error|on )/ then
    puts line.chomp
  when /^(goto|shift| +\[|$)/ then # racc
    # do nothing
  # when /^Reading a token: Now at end of input./ then
  #   # puts "EOF"
  # when /^Reading a token: Next token is token (.+)/ then
  #   puts "READ: #{$1.inspect}"
  when /^accept/ then
    puts "DONE"
  else
    puts "unparsed: #{line.chomp}"
  end
end
