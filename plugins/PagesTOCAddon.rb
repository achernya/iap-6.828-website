module PagesTOCAddon
  def table_of_contents
    return @content if @content
    content = @model.collection.master.render(@model.content)
    Ruhoh::Converter::Markdown.tocconvert(content)
  end
end

Ruhoh.model('pages').send(:include, PagesTOCAddon)
