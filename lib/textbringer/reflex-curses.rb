require 'reflex'
require 'beeps'

module Textbringer
  module ReflexCurses
    COLOR_BLACK   = 0
    COLOR_RED     = 1
    COLOR_GREEN   = 2
    COLOR_YELLOW  = 3
    COLOR_BLUE    = 4
    COLOR_MAGENTA = 5
    COLOR_CYAN    = 6
    COLOR_WHITE   = 7

    A_BOLD      = 0
    A_UNDERLINE = 0
    A_REVERSE   = 0

    ALT_0 = ?0.ord
    ALT_9 = ?9.ord
    ALT_A = ?a.ord
    ALT_Z = ?z.ord

    PDC_KEY_MODIFIER_CONTROL = 0
    PDC_KEY_MODIFIER_ALT     = 0

    class Screen < Reflex::Window
      def self.init()
        @current = Screen.new width: 640, height: 480, x: 100, y: 200
        @current.title = "#{Textbringer.name} #{Textbringer::VERSION}"
        @current.show
      end

      def self.close()
        @current.close
        @current = nil
      end

      def self.current()
        @current
      end

      def initialize(...)
        super
        @cury = @curx = 0
        @keys         = []
        @command_loop = Fiber.new do
          loop do
            Controller.current.command_loop(TOP_LEVEL_TAG)
            Window.redisplay
          end
        rescue Exception => e
          if !e.is_a?(SystemExit)
            Buffer.dump_unsaved_buffers(CONFIG[:buffer_dump_dir])
          end
          raise
        end
      end

      attr_reader :keys

      def setpos(y, x)
        @cury, @curx = y, x
      end

      def windows()
        @windows ||= []
      end

      def font()
        @font = Rays::Font.new "Menlo", 24
      end

      def fonth()
        @fonth ||= font.height
      end

      def fontw()
        @fontw ||= font.width("X")
      end

      def to_screen(posx, posy)
        [fontw * posx, fonth * posy]
      end

      def on_update(e)
        @command_loop.resume
      end

      def on_draw(e)
        e.painter.push font: font do |p|
          windows.each do |window|
            window.draw p
          end
          p.fill :white
          p.rect(*to_screen(@curx, @cury), fontw, fonth)
        end
      end

      def on_key_down(e)
        @keys.push e.chars if e.chars
      end
    end

    def self.init_screen()
      Screen.init
    end

    def self.close_screen()
      Screen.close
    end

    def self.doupdate()
    end

    def self.get_key_modifiers()
      0
    end

    def self.save_key_modifiers(*args)
    end

    def self.lines()
      Screen.current.then {(_1.height / _1.fonth).floor} - 1
    end

    def self.cols()
      Screen.current.then {(_1.width / _1.fontw).floor} - 1
    end

    def self.echo()
    end

    def self.noecho()
    end

    def self.nl()
    end

    def self.nonl()
    end

    def self.raw()
    end

    def self.noraw()
    end

    def self.init_pair(*args)
    end

    def self.color_pair(*args)
    end

    def self.colors()
      []
    end

    def self.start_color()
    end

    def self.has_colors?()
      false
    end

    def self.use_default_colors()
    end

    def self.assume_default_colors(*args)
    end

    def self.beep()
      @beeper ||= Beeps::Oscillator.new >> Beeps::Gain.new(gain: 0.05)
      Beeps::Sound.new(@beeper, 0.03).play
    end

    class Window
      attr_reader :cury, :curx, :maxy, :maxx, :timeout

      attr_accessor :nodelay, :keypad

      def initialize(height, width, y, x)
        @cury = @curx = @maxy = @maxx = 0
        @nodelay = @keypad = false
        @posy, @posx = y, x
        @timeout     = -1

        Screen.current.windows.push self
        resize height, width
      end

      def close()
        Screen.current.windows.delete self
      end

      def redraw()
        Screen.current.redraw
      end

      def resize(height, width)
        @maxy, @maxx = height, width
        @image = Rays::Image.new(*to_screen(@maxx, @maxy).map(&:ceil))
        @lines = @maxy.times.map {" " * @maxx}
        redraw
      end

      def move(y, x)
        @posy, @posx = y, x
      end

      def get_char()
        process_message_loop
        keys = Screen.current.keys
        if blocking?
          if @timeout >= 0
            timeout = Time.now.to_f + @timeout / 1000.0
            process_message_loop while keys.empty? && Time.now.to_f < timeout
          else
            process_message_loop while keys.empty?
          end
        end
        keys.shift
      end

      def addstr(str)
        str  = str[0, @maxx - @curx] if (@curx + str.size) > @maxx
        line = @lines[@cury]
        line[@curx, str.size] = str
        setpos @cury, @curx + str.size
        @image.paint do |p|
          x, y = to_screen(0, @cury)
          p.fill :black
          p.rect(x, y, *to_screen(@maxx, 1))
          p.fill :white
          p.font Screen.current.font
          p.text line, x, y
        end
        redraw
      end

      def erase()
      end

      def setpos(y, x)
        @cury, @curx = y, x
        Screen.current.setpos y, x
      end

      def scrollok(ok)
      end

      def idlok(ok)
      end

      def clrtoeol()
      end

      def noutrefresh()
        Screen.current.redraw
      end

      def attrset(*args)
      end

      def attron(*args)
      end

      def attroff(*args)
      end

      def draw(painter)
        painter.image(@image, *to_screen(@posx, @posy))
      end

      private

      def to_screen(posx, posy)
        Screen.current.to_screen posx, posy
      end

      def blocking?()
        !nodelay
      end

      def process_message_loop()
        Fiber.yield rescue FiberError
      end
    end
  end
end

Curses = Textbringer::ReflexCurses
