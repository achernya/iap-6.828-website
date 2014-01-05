require 'redcarpet'

class Ruhoh
  module Converter
    module Markdown

      def self.extensions
        ['.md', '.markdown']
      end
      
      def self.convert(content)
        require 'redcarpet'
        toc = Redcarpet::Markdown.new(Redcarpet::Render::HTML_TOC)
        markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(:with_toc_data => true),
          :autolink => true, 
          :fenced_code_blocks => true,
	  :tables => true,
        )
        #toc.render(content)
        markdown.render(content)
      end
    end
  end
end
