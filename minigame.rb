require 'fileutils'

module DeltaWhy
  Mcl.reloadable(:Minigames, parent = DeltaWhy)

  ## Minigame world switcher
  # !minigame <name>
  # !minigame list
  # !minigame default
  # !minigame reset
  class Minigames < Mcl::Handler
    def setup
      register_minigame(:member)
    end

    def usage(player)
      d = [["<name>", "switch to a new minigame"],
           ["list", "list available minigames"],
           ["default", "switch to the default world"],
           ["reset", "restart the current minigame"]]
      d.each do |cmd, desc|
        trawt(player, "Minigames", {text: cmd, color: "gold"},
              {text: " #{desc}", color: "reset"})
      end
    end

    def register_minigame acl_level
      register_command :minigame, :minigames, desc: "switches minigames", acl: acl_level do |player, args|
        if args[0] =~ /\A[0-9a-z_\-\/]+\z/i
          case args[0]
          when "help"
            usage(player)
          when "list"
            games = Dir["#{$mcl.server.root}/minigames/**/level.dat"].map {|path| path.sub("#{$mcl.server.root}/minigames/","").sub(/\/level.dat\z/, "")}
            trawt(player, "Minigames", {text: games.join(", "), color: "gold"})
          when "default"
            if valid_world? $mcl.server.world
              trawt(player, "Minigames", {text: "Swapping to default world...", color: "aqua"})
              swap_default
            else
              trawt(player, "Minigames", {text: "You're not in a minigame.", color: "red"})
            end
          when "reset", $mcl.server.world
            if valid_world? $mcl.server.world
              trawt(player, "Minigames", {text: "Resetting the world...", color: "aqua"})
              swap_game($mcl.server.world)
            else
              trawt(player, "Minigames", {text: "Not a minigame - can't reset this world!", color: "red"})
            end
          else
            if valid_world? args[0]
              trawt(player, "Minigames", {text: "Swapping to game ", color: "aqua"}, {text: args[0], color: "light_purple"}, {text: "...", color: "aqua"})
              swap_game(args[0])
            else
              trawt(player, "Minigames", {text: "No such game.", color: "red"})
            end
          end
        else
          usage(player)
        end
      end
    end

    def valid_world? world
      File.exists? "#{$mcl.server.root}/minigames/#{world}/level.dat"
    end

    def swap_game game
      current_world = $mcl.server.world

      announce_server_restart
      async do
        sleep 5
        FileUtils.rm_r "#{$mcl.server.root}/#{game}/"
        FileUtils.cp_r "#{$mcl.server.root}/minigames/#{game}/", $mcl.server.root
        FileUtils.cp "#{$mcl.server.root}/server.properties", "#{$mcl.server.root}/default.properties" if current_world == "world"
        FileUtils.rm "#{$mcl.server.root}/server.properties"
        if File.exists? "#{$mcl.server.root}/minigames/#{game}.properties"
          FileUtils.cp "#{$mcl.server.root}/minigames/#{game}.properties", "#{$mcl.server.root}/server.properties"
        elsif File.exists? "#{$mcl.server.root}/minigames/minigame.properties"
          FileUtils.cp "#{$mcl.server.root}/minigames/minigame.properties", "#{$mcl.server.root}/server.properties"
        else
          FileUtils.cp "#{$mcl.server.root}/default.properties", "#{$mcl.server.root}/server.properties"
        end
        $mcl.sync { $mcl.server.update_property "level-name", game }
        $mcl.sync { $mcl_reboot = true }
      end
    end

    def swap_default
      current_world = $mcl.server.world

      announce_server_restart
      async do
        sleep 5
        if valid_world? current_world
          FileUtils.rm_r "#{$mcl.server.root}/#{current_world}/"
        end
        if File.exists? "#{$mcl.server.root}/default.properties"
          FileUtils.rm "#{$mcl.server.root}/server.properties"
          FileUtils.cp "#{$mcl.server.root}/default.properties", "#{$mcl.server.root}/server.properties"
        end
        $mcl.sync { $mcl.server.update_property "level-name", "world" }
        $mcl.sync { $mcl_reboot = true }
      end
    end
  end
end
