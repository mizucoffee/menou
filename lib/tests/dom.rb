register_test('dom') do |option, test_tb, path|
 
  query = (option['query'].nil?) ? "" : URI.encode_www_form(option['query'])
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  driver = Selenium::WebDriver.for :chrome, options: options
  driver.get "http://localhost:4567" + option['path'] + "?" + query

  option['expect'].each do |expect|
    case expect['target']
    when 'page_title'
      test_tb.task("ページ名") do |error|
        error.call "ページ名が正しくありません 結果: \"#{driver.title}\" 期待する値: \"#{expect['expect']}\"" if driver.title != expect['expect']
      end
    when 'content'
      test_tb.task("要素'#{expect['selector']}'の値") do |error|
        elements = driver.find_elements(:css, expect['selector'])
        next error.call "要素'#{expect['selector']}'が存在しません" if elements.empty?
        contents = elements.map { |a| a.text }
        expect['expect'].each_with_index do |e, i|
          error.call "要素'#{expect['selector']}[#{i}]'の値が正しくありません 結果: \"#{contents[i]}\" 期待する値: \"#{e}\"" if contents[i] != e
        end
      end
    when 'displayed'
      test_tb.task("要素'#{expect['selector']}'の表示状態") do |error|
        elements = driver.find_elements(:css, expect['selector'])
        next error.call "要素'#{expect['selector']}'が存在しません" if elements.empty?

        elements.each do |e|
          error.call "要素'#{expect['selector']}'の表示状態が正しくありません 結果: #{e.displayed?} 期待する値: #{expect['expect']}" unless e.displayed? == expect['expect']
        end
      end
    end
  end

  driver.quit
end