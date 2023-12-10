def generate_pdf(data)
  report = Thinreports::Report.new layout: 'path/to/your_template.tlf'

  report.start_new_page do |page|
    # テンプレートの各フィールドにデータを埋め込む
    page.item(:field_id_1).value(data[:value1])
    page.item(:field_id_2).value(data[:value2])
    # 他のフィールドにもデータを設定...
  end

  # PDFデータを生成
  report.generate
end