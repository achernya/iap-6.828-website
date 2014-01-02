require 'redcarpet'
module Redcarpet::Render
  class GithubStyleTitles < HTML
    #
    # FIXME: this is a temporary workaround until the
    #        following (merged) pull request is included
    #        in the next gem release of Redcarpet 3:
    #        https://github.com/vmg/redcarpet/pull/186
    #
    def header(title, level)
      fragment = title.downcase.gsub(/\W+/, '-')
 
      # make the fragment unique by appending an incremented counter
      @fragments ||= []
      if @fragments.include? fragment
        fragment += '_1'
        fragment = fragment.next while @fragments.include? fragment
      end
      @fragments << fragment
 
      # generate HTML for this header containing the above fragment
      [?\n,
 
        %{<a name="#{fragment}" href="##{fragment}" class="anchor">},
          %{<span class="anchor-icon">},
          '</span>',
        '</a>',
 
        %{<h#{level} id="#{fragment}">},
          title,
        "</h#{level}>",
 
      ?\n].join
    end
  end
end


class Ruhoh
  module Converter
    module Markdown

      def self.extensions
        ['.md', '.markdown']
      end
      
      def self.convert(content)
        require 'redcarpet'
        markdown = Redcarpet::Markdown.new(Redcarpet::Render::GithubStyleTitles.new(:with_toc_data => true),
          :autolink => true, 
          :fenced_code_blocks => true,
	  :tables => true,
        )
        markdown.render(content)
      end
    end
  end
end
