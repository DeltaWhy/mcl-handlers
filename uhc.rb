module DeltaWhy
  Mcl.reloadable(:UHC, parent = DeltaWhy)
  ## UHC
  # !uhc help
  # !uhc option [<key> [<value>]]
  # !uhc pre
  # !uhc start
  # !uhc stop
  # !uhc time
  class UHC < Mcl::Handler
    class << self
      attr_accessor :start_time
    end

    def setup
      register_uhc(:mod)
      register_parsers
    end

    def usage(player)
      d = [["option [<key> [<value>]]", "get or set game options"],
           ["pre", "set up for pre-game"],
           ["start", "start the game"],
           ["stop", "stop the game"],
           ["time", "see the elapsed time"]]
      d.each do |cmd, desc|
        trawt(player, "UHC", {text: cmd, color: "gold"},
              {text: " #{desc}", color: "reset"})
      end
    end

    def register_uhc acl_level
      register_command :uhc, desc: "UHC game helpers", acl: acl_level do |player, args|
        case args[0]
        when "option"
          if args.length == 1
            UHC.options.each {|k,v|
              trawt(player, "UHC", {text: "#{k}: ", color: "aqua"},
                    {text: v, color: "gold"})
            }
          elsif args.length == 2
            v = UHC.options[args[1].to_sym]
            if v != nil
              trawt(player, "UHC", {text: "#{args[1].to_sym}: ", color: "aqua"},
                    {text: v, color: "gold"})
            else
              trawt(player, "UHC", {text: "No such option.", color: "red"})
            end
          elsif args.length == 3
            v = UHC.options[args[1].to_sym]
            if v == nil
              trawt(player, "UHC", {text: "No such option.", color: "red"})
            elsif v.is_a? Integer
              UHC.options[args[1].to_sym] = args[2].to_i
            elsif v == false || v == true
              UHC.options[args[1].to_sym] = (args[2].downcase != "false")
            elsif v.is_a? String
              UHC.options[args[1].to_sym] = args[2]
            end
          else
            usage(player)
          end
        when "pre"
          $mcl.server.invoke "/time set day"
          $mcl.server.invoke "/difficulty peaceful"
          $mcl.server.invoke "/gamerule doDaylightCycle false"
          $mcl.server.invoke "/gamerule naturalRegeneration true"
          $mcl.server.invoke "/setworldspawn 0 255 0"
          $mcl.server.invoke "/worldborder center 0 0"
          $mcl.server.invoke "/worldborder set #{2*UHC.options[:border_radius]}" if UHC.options[:border_radius] > 0
          $mcl.server.invoke "/scoreboard objectives add health health Health"
          $mcl.server.invoke "/scoreboard objectives setdisplay list health"
          $mcl.server.invoke "/scoreboard objectives setdisplay belowName health"
        when "start"
          $mcl.server.invoke "/effect @a[m=0] minecraft:saturation 1 100"
          $mcl.server.invoke "/effect @a[m=0] minecraft:instant_health 1 100"
          $mcl.server.invoke "/effect @a[m=0] minecraft:slowness 9999 100"
          $mcl.server.invoke "/effect @a[m=0] minecraft:mining_fatigue 9999 100"
          $mcl.server.invoke "/effect @a[m=0] minecraft:blindness 9999"
          $mcl.server.invoke "/clear @a[m=0]"
          $mcl.server.invoke "/spreadplayers 0 0 #{UHC.options[:min_scatter_distance]} #{UHC.options[:scatter_radius]} true @a[m=0]" if UHC.options[:do_scatter]
          traw "@a", "Game starts in #{UHC.options[:start_delay]} seconds!", color: "gold"
          schedule "start UHC", Time.now+UHC.options[:start_delay].seconds, StartTask.new
        when "stop"
          Mcl::Task.where(name: "episode marker").destroy_all
          traw "@a", "Game stopped.", color: "gold"
          UHC.start_time = nil
        when "time"
          if UHC.start_time
            duration = (Time.now - UHC.start_time)
            hours, duration = duration.divmod 3600
            minutes, seconds = duration.divmod 60
            time = sprintf "%d:%02d:%02d", hours, minutes, seconds
            traw player, "#{time} elapsed.", color: "light_purple"
          else
            traw player, "Game is not running.", color: "light_purple"
          end
        else
          usage(player)
        end
      end
    end

    def register_parsers
      register_parser(/\A(\S+) (fell|was doomed to fall|was struck by lightning|went up in flames|walked into fire whilst fighting|burned to death|was burned to a crisp whilst fighting|tried to swim in lava|suffocated in a wall|drowned|starved to death|was pricked to death|walked into a cactus whilst trying to escape|died|blew up|was blown up by|was killed by magic|withered away|was squashed by a falling|was (slain|shot|fireballed|pummeled|killed) by|was killed trying to hurt|hit the ground too hard)/) do |res, r|
        $mcl.log.info("#{r[1]} died")
        next unless UHC.start_time
        $mcl.server.invoke "/gamemode 3 #{r[1]}"
        $mcl.log.info("invoked gamemode")
        if UHC.options[:deathban]
          traw r[1], "Thanks for playing! You will be kicked in 30 seconds.", color: "gold"
          schedule "deathban #{r[1]}", Time.now+30.seconds, CommandTask.new("/ban #{r[1]}")
          $mcl.log.info("scheduled deathban")
        end
      end
    end

    def self.options
      @options ||= {start_delay: 15,
                    deathban: false,
                    episode_duration: -1,
                    border_radius: 1500,
                    min_border_radius: -1,
                    border_duration: -1,
                    do_scatter: true,
                    scatter_radius: 1000,
                    min_scatter_distance: 100,
                   }
    end

    class StartTask
      def initialize
      end

      def perform!
        $mcl.server.invoke "/difficulty hard"
        $mcl.server.invoke "/gamerule doDaylightCycle true"
        $mcl.server.invoke "/time set day"
        $mcl.server.invoke "/gamerule naturalRegeneration false"
        $mcl.server.invoke "/effect @a[m=0] minecraft:slowness 0"
        $mcl.server.invoke "/effect @a[m=0] minecraft:mining_fatigue 0"
        $mcl.server.invoke "/effect @a[m=0] minecraft:blindness 0"
        if UHC.options[:border_duration] > 0 && UHC.options[:min_border_radius] >= 0
          $mcl.server.invoke "/worldborder set #{2*UHC.options[:min_border_radius]} #{UHC.options[:border_duration]}"
        end
        $mcl.server.traw "@a", "Let the games begin!", color: "red"
        $mcl.scheduler.schedule "episode marker", Time.now+UHC.options[:episode_duration].minutes, EpisodeTask.new(UHC.options[:episode_duration]) if UHC.options[:episode_duration] > 0
        UHC.start_time = Time.now
      end
    end

    class EpisodeTask
      def initialize(time)
        @time = time
      end

      def perform!
        $mcl.server.traw "@a", "#{@time} minutes elapsed.", color: "light_purple"
        $mcl.scheduler.schedule "episode marker", Time.now+UHC.options[:episode_duration].minutes, EpisodeTask.new(@time+UHC.options[:episode_duration])
      end
    end

    class CommandTask
      def initialize command
        @command = command
      end

      def perform!
        $mcl.server.invoke @command
      end
    end
  end
end
