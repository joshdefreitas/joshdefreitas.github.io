# Source: https://stackoverflow.com/questions/19169849/how-to-get-markdown-processed-content-in-jekyll-tag-plugin

module Jekyll
  module Tags
    class AccordionTag < Liquid::Block

      def initialize(tag_name, type, tokens)
        super
        type.strip!
        @type = type
      end

      def render(context)
        site = context.registers[:site]
        converter = site.find_converter_instance(::Jekyll::Converters::Markdown)
        output = converter.convert(super(context))
        "<details><summary>#{@type}</summary>#{output}</details>"
      end
    end
  end
end

Liquid::Template.register_tag('accordion', Jekyll::Tags::AccordionTag)
