module DeltaWhy
  Mcl.reloadable(:Teams, parent = DeltaWhy)
  ## Teams
  # !teams help
  # !teams setup
  # !teams randomize (-t <num_teams> | -p <num_players>)
  # !teams clear
  # !teams spectate
  # !teams join <team> [<player> ...]
  class Teams < Mcl::Handler
    def setup
      register_teams(:guest, setup: :mod, randomize: :mod, clear: :mod,
                     spectate: :guest, join: :member, join_others: :mod)
      register_parsers
    end

    # The order determines which teams will be used first
    def self.colors
      ["red", "blue", "green", "gold", "light_purple", "aqua", "white", "black",
       "dark_red", "dark_blue", "dark_green", "yellow", "dark_aqua", "dark_purple", "gray", "dark_gray"]
    end

    def usage(player)
      d = [["setup", "create default teams"],
           ["randomize (-t <num_teams> | -p <num_players>)", "randomly assign teams"],
           ["clear", "delete default teams"],
           ["spectate", "become a spectator"],
           ["join <team> [<player> ...]", "join a team or add players to a team"]]
      d.each do |cmd, desc|
        trawt(player, "Teams", {text: cmd, color: "gold"},
              {text: " #{desc}", color: "reset"})
      end
    end

    def register_teams acl_level, acl_levels
      register_command :teams, desc: "Team setup helpers", acl: acl_level do |player, args|
        case args[0]
        when "setup"
          acl_verify(player, acl_levels[:setup])
          Teams.colors.each do |c|
            n = c.split("_").map(&:capitalize).join(" ")
            $mcl.server.invoke "/scoreboard teams remove #{c}"
            $mcl.server.invoke "/scoreboard teams add #{c} #{n}"
            $mcl.server.invoke "/scoreboard teams option #{c} color #{c}"
          end
        when "randomize"
          acl_verify(player, acl_levels[:randomize])
          num_teams, num_players = nil, nil
          if args.length != 3
            usage(player)
            next
          elsif args[1] == "-t"
            num_teams = args[2].to_i
          elsif args[1] == "-p"
            num_players = args[2].to_i
          else
            usage(player)
            next
          end

          Teams.spectators.clear
          $mcl.server.invoke "/testfor @a[m=3]"
          schedule "randomize teams", Time.now+1.second, RandomizeTask.new(player, num_teams, num_players)
        when "clear"
          acl_verify(player, acl_levels[:clear])
          Teams.colors.each do |c|
            $mcl.server.invoke "/scoreboard teams remove #{c}"
          end
        when "spectate"
          acl_verify(player, acl_levels[:spectate])
          $mcl.server.invoke "/gamemode 3 #{player}"
        when "join"
          acl_verify(player, acl_levels[:join])
          if args.length < 2
            usage(player)
            next
          elsif args.length == 2
            $mcl.server.invoke "/scoreboard teams join #{args[1]} #{player}"
          else
            acl_verify(player, acl_levels[:join_others])
            args[2..args.length].each do |p|
              $mcl.server.invoke "/scoreboard teams join #{args[1]} #{p}"
            end
          end
        else
          usage(player)
        end
      end
    end

    def register_parsers
      register_parser(/\AFound (.+)\z/) do |res, r|
        Teams.spectators << r[1]
      end
      register_parser(/\A(\S+) (fell|was doomed to fall|was struck by lightning|went up in flames|walked into fire whilst fighting|burned to death|was burned to a crisp whilst fighting|tried to swim in lava|suffocated in a wall|drowned|starved to death|was pricked to death|walked into a cactus whilst trying to escape|died|blew up|was blown up by|was killed by magic|withered away|was squashed by a falling|was (slain|shot|fireballed|pummeled|killed) by|was killed trying to hurt|hit the ground too hard)\z/) do |res, r|
        $mcl.log.info("#{r[1]} died")
      end
    end

    class RandomizeTask
      def initialize(player, num_teams, num_players)
        @player = player
        @num_teams = num_teams
        @num_players = num_players
      end

      def perform!
        players = Mcl::Player.online.map(&:nickname)
        Teams.spectators.each {|p| players.delete(p)}
        @num_teams = players.length / @num_players unless @num_teams
        if @num_teams > Teams.colors.length
          trawt(@player, "Teams", {text: "Not enough teams.", color: "red"})
          return
        end
        teams = Teams.colors.first(@num_teams)
        assignments = teams.cycle.first(players.length).shuffle
        players.zip(assignments).each do |p,t|
          $mcl.server.invoke "/scoreboard teams join #{t} #{p}"
        end
      end
    end

    def self.spectators
      @spectators ||= []
    end
  end
end
