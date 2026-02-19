# Minimal SketchUp API stubs for running unit tests outside SketchUp.

$__file_loaded_registry ||= {}

def file_loaded?(path)
  $__file_loaded_registry[path] == true
end

def file_loaded(path)
  $__file_loaded_registry[path] = true
end

module UI
  MB_YESNO = 4
  MB_YESNOCANCEL = 3
  IDYES = 6
  IDCANCEL = 2

  class Menu
    def add_item(_name)
      true
    end

    def add_submenu(_name)
      self
    end
  end

  class Toolbar
    def initialize(_name); end
    def add_item(_cmd); end
    def restore; end
  end

  class Command
    attr_accessor :small_icon, :large_icon, :tooltip, :status_bar_text

    def initialize(_name); end
  end

  class HtmlDialog
    STYLE_DIALOG = 0

    def initialize(**_opts); end
    def set_file(_path); end
    def set_html(_html); end
    def show; end
    def visible?; false; end
    def bring_to_front; end
    def execute_script(_js); end
    def add_action_callback(_name); end
  end

  class WebDialog
    def initialize(*_args); end
    def set_html(_html); end
    def show; end
    def execute_script(_js); end
  end

  def self.menu(_name)
    Menu.new
  end

  def self.add_context_menu_handler
    yield(Menu.new) if block_given?
  end

  def self.messagebox(_message, *_args)
    IDYES
  end

  def self.inputbox(_prompts, defaults, *_args)
    defaults
  end

  def self.select_directory(**_opts)
    nil
  end

  def self.openURL(_url)
    true
  end
end

module Sketchup
  class << self
    attr_accessor :status_text
  end

  def self.active_model
    @active_model ||= Object.new
  end

  def self.read_default(_key, _name, default = nil)
    default
  end

  def self.write_default(_key, _name, _value)
    true
  end

  def self.format_length(value)
    value.to_s
  end
end
