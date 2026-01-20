#-------------------------------------------------------------------------------
# Calculator – Core Implementation
#-------------------------------------------------------------------------------
# Provides a simple expression-evaluating calculator using an HtmlDialog.
# Parses arithmetic expressions safely without eval. It supports + - * / ^
# and parentheses.
#-------------------------------------------------------------------------------
require 'sketchup.rb'

module AP
  module Plugins
    module Calculator

      #-------------------------------------------------------------------------
      #  Expression Evaluator (Lightweight Shunting Yard + RPN evaluator)
      #-------------------------------------------------------------------------
      module Evaluator
        extend self

        OPERATORS = {
          '+' => { prec: 1, assoc: :left,  op: ->(a, b) { a + b } },
          '-' => { prec: 1, assoc: :left,  op: ->(a, b) { a - b } },
          '*' => { prec: 2, assoc: :left,  op: ->(a, b) { a * b } },
          '/' => { prec: 2, assoc: :left,  op: ->(a, b) { a / b } },
          '^' => { prec: 3, assoc: :right, op: ->(a, b) { a**b } }
        }.freeze

        TOKEN_REGEX = /\d+(?:\.\d+)?|[+\-*\/\^()]/.freeze

        def evaluate(expr)
          rpn = to_rpn(tokenize(expr))
          compute_rpn(rpn)
        rescue => e
          raise ArgumentError, "Invalid expression: #{e.message}"
        end

        private

        def tokenize(expr)
          tokens = expr.scan(TOKEN_REGEX).map(&:strip).reject(&:empty?)
          raise 'Empty expression' if tokens.empty?
          tokens
        end

        def to_rpn(tokens)
          output = []
          stack  = []
          tokens.each do |token|
            if number?(token)
              output << token.to_f
            elsif OPERATORS.key?(token)
              while !stack.empty? && OPERATORS.key?(stack.last)
                top = stack.last
                break if (OPERATORS[token][:assoc] == :right && OPERATORS[token][:prec] < OPERATORS[top][:prec]) ||
                         (OPERATORS[token][:assoc] == :left  && OPERATORS[token][:prec] <= OPERATORS[top][:prec])
                output << stack.pop
              end
              stack << token
            elsif token == '('
              stack << token
            elsif token == ')'
              until stack.empty? || stack.last == '('
                output << stack.pop
              end
              raise 'Mismatched parentheses' if stack.empty?
              stack.pop # Remove '('
            else
              raise "Unknown token #{token}"
            end
          end
          until stack.empty?
            raise 'Mismatched parentheses' if ['(', ')'].include?(stack.last)
            output << stack.pop
          end
          output
        end

        def compute_rpn(rpn)
          stack = []
          rpn.each do |token|
            if token.is_a?(Numeric)
              stack << token
            else
              raise 'Insufficient operands' if stack.size < 2
              b = stack.pop
              a = stack.pop
              stack << OPERATORS[token][:op].call(a, b)
            end
          end
          raise 'Too many operands' unless stack.size == 1
          stack.first
        end

        def number?(token)
          token =~ /\A\d+(?:\.\d+)?\z/
        end
      end # module Evaluator

      #-------------------------------------------------------------------------
      #  UI Dialog
      #-------------------------------------------------------------------------
      module UIHelper
        extend self

        def show_calculator
          plugin_dir = File.dirname(__FILE__)
          html_path = File.join(plugin_dir, 'ui', 'calculator.html')

          # Ensure a local copy of Math.js is present so the calculator works offline.
          ui_dir = File.join(plugin_dir, 'ui')
          math_local = File.join(ui_dir, 'math.min.js')
          unless File.exist?(math_local)
            begin
              require 'open-uri'
              data = URI.open('https://cdnjs.cloudflare.com/ajax/libs/mathjs/10.6.4/math.min.js', &:read)
              File.write(math_local, data)
            rescue => e
              # It's okay if the download fails – the HTML will fall back to the CDN.
              puts "[AP::Calculator] Could not download Math.js locally: #{e.message}"
            end
          end
          unless File.exist?(html_path)
            UI.messagebox('Calculator UI not found.')
            return
          end

          @dlg ||= UI::HtmlDialog.new(dialog_title: 'Calculator', width: 350, height: 420, style: UI::HtmlDialog::STYLE_DIALOG)
                    @dlg.set_file(html_path)
          @dlg.show
        end # show_calculator
=begin removed duplicate HTML block
          plugin_dir = File.dirname(__FILE__)
          html_path = File.join(plugin_dir, 'ui', 'calculator.html')

          # Ensure a local copy of Math.js is present so the calculator works offline.
          ui_dir = File.join(plugin_dir, 'ui')
          math_local = File.join(ui_dir, 'math.min.js')
          unless File.exist?(math_local)
            begin
              require 'open-uri'
              data = URI.open('https://cdnjs.cloudflare.com/ajax/libs/mathjs/10.6.4/math.min.js', &:read)
              File.write(math_local, data)
            rescue => e
              # It's okay if the download fails – the HTML will fall back to the CDN.
              puts "[AP::Calculator] Could not download Math.js locally: #{e.message}"
            end
          end
          unless File.exist?(html_path)
            UI.messagebox('Calculator UI not found.')
            return
          end
            <!DOCTYPE html>
            <html>
            <head>
              <meta charset="utf-8">
              <title>Calculator</title>
              <style>
                body { font-family: sans-serif; margin: 8px; }
                #expr { width: 260px; }
                #result { margin-top: 8px; font-weight: bold; }
              </style>
            </head>
            <body>
              <input type="text" id="expr" placeholder="Expression" />
              <button onclick="sketchup.evaluate(document.getElementById('expr').value)">=</button>
              <p id="result"></p>
              <script>
                function sketchupCallback(res){ document.getElementById('result').innerText = res; }
              </script>
            </body>
            </html>
          HTML

          @dlg ||= UI::HtmlDialog.new(dialog_title: 'Calculator', width: 350, height: 420, style: UI::HtmlDialog::STYLE_DIALOG)
                    @dlg.set_file(html_path)
            begin
              res = Evaluator.evaluate(expr.to_s)
              @dlg.execute_script("sketchupCallback(" + res.to_s.inspect + ")")
            rescue => e
              UI.messagebox("Error: #{e.message}")
            end
          end
          @dlg.show
                  @dlg.show
        end
=end
        # Commented out duplicate obsolete block
        # rescue => e
        #   UI.messagebox("Error: #{e.message}")
        # end
        # end
        # @dlg.show
        # @dlg.show
      end # module UIHelper

      #-------------------------------------------------------------------------
      #  Menu & Toolbar
      #-------------------------------------------------------------------------
      unless file_loaded?(__FILE__)
        menu = UI.menu('Plugins')
        menu.add_item('Calculator') { UIHelper.show_calculator }

        toolbar = UI::Toolbar.new('Calculator')
        cmd = UI::Command.new('Calculator') { UIHelper.show_calculator }
        cmd.tooltip = 'Open calculator'
        base_dir = File.dirname(__FILE__)
        # Prefer icons inside an "icons" subfolder; otherwise fall back to files in the root.
        small_in_icons = File.join(base_dir, 'icons', 'calculator_24.png')
        large_in_icons = File.join(base_dir, 'icons', 'calculator_48.png')
        small_root     = File.join(base_dir, 'calculator_24.png')
        large_root     = File.join(base_dir, 'calculator_48.png')

        if File.exist?(small_in_icons)
          cmd.small_icon = 'icons/calculator_24.png'
        elsif File.exist?(small_root)
          cmd.small_icon = 'calculator_24.png'
        else
          cmd.small_icon = ''
        end

        if File.exist?(large_in_icons)
          cmd.large_icon = 'icons/calculator_48.png'
        elsif File.exist?(large_root)
          cmd.large_icon = 'calculator_48.png'
        else
          cmd.large_icon = cmd.small_icon
        end
        toolbar.add_item(cmd)
        toolbar.restore
      end

    end # module Calculator
  end   # module Plugins
end     # module AP

#-------------------------------------------------------------------------------

file_loaded(__FILE__)

#-------------------------------------------------------------------------------
