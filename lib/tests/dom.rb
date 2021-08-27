register_test('dom') do |option, test_tb, path, driver, screenshot|
  query = (option['query'].nil?) ? "" : URI.encode_www_form(option['query'])
  driver.get "http://localhost:4567" + option['path'] + "?" + query
  sleep 0.5

  option['expect'].each do |expect|
    case expect['target']
    when 'page_title'
      test_tb.task("ページ名の検証") do |error|
        error.call "ページ名が正しくありません", driver.title, expect['expect'] if driver.title != expect['expect']
      end
    when 'content'
      test_tb.task("要素'#{expect['selector']}'の値") do |error|
        elements = driver.find_elements(:css, expect['selector'])
        next error.call "要素'#{expect['selector']}'が存在しません" if elements.empty?
        contents = elements.map { |a| a.text }
        expect['expect'].each_with_index do |e, i|
          error.call "要素'#{expect['selector']}[#{i}]'の値が正しくありません", contents[i], e if "#{contents[i]}" != "#{e}"
        end
      end
    when 'displayed'
      test_tb.task("要素'#{expect['selector']}'の表示状態") do |error|
        elements = driver.find_elements(:css, expect['selector'])
        next error.call "要素'#{expect['selector']}'が存在しません" if elements.empty?
        elements.each do |e|
          error.call "要素'#{expect['selector']}'の表示状態が正しくありません", e.displayed?, expect['expect'] unless e.displayed? == expect['expect']
        end
      end
    when 'exists'
      test_tb.task("要素'#{expect['selector']}'の存在状態") do |error|
        elements = driver.find_elements(:css, expect['selector'])
        state = !elements.empty?
        error.call "要素'#{expect['selector']}'の存在状態が正しくありません", state, expect['expect'] unless state == expect['expect']
      end
    when 'path'
      test_tb.task("URLの検証") do |error|
        uri = URI.parse(driver.current_url)
        path = uri.path
        path += "?#{uri.query}" unless uri.query.nil?
        next error.call "URLが正しくありません", path, expect['expect'] unless path == expect['expect']
      end
    when 'css'
      test_tb.task("要素'#{expect['selector']}'のスタイル") do |error|
        elements = driver.find_elements(:css, expect['selector'])
        next error.call "要素'#{expect['selector']}'が存在しません" if elements.empty?

        expect['expect'].each_with_index do |e, i|
          error.call "要素'#{expect['selector']}[#{i}]'の#{e['property']}プロパティが正しくありません", elements[i].css_value(e['property']), e['value'] if elements[i].css_value(e['property']) != e['value']
        end
      end
    when 'input'
      test_tb.task("要素'#{expect['selector']}'に'#{expect['text']}'と入力") do |error|
        elements = driver.find_elements(:css, expect['selector'])
        next error.call "要素'#{expect['selector']}'が存在しません" if elements.empty?
        elements[0].clear
        elements[0].send_keys(expect['text'])
      end
    when 'click'
      test_tb.task("要素'#{expect['selector']}'をクリック") do |error|
        elements = driver.find_elements(:css, expect['selector'])
        next error.call "要素'#{expect['selector']}'が存在しません" if elements.empty?
        elements[0].click
      end
    when 'wait'
      test_tb.task("要素'#{expect['selector']}'の待機後の値") do |error|
        unless expect['second'].nil?
          sleep expect['second']
        else
          wait = Selenium::WebDriver::Wait.new(:timeout => expect['timeout'])
          begin
            wait.until {
              elements = driver.find_elements(:css, expect['selector'])
              next false if elements.empty?
              elements[0].text == expect['expect'] || expect['expect'].nil?
            }
          rescue => exception
            elements = driver.find_elements(:css, expect['selector'])
            next error.call "要素'#{expect['selector']}'が存在しません" if elements.empty?
            next error.call "要素'#{expect['selector']}[0]'の値が正しくありません", elements[0].text, expect['expect']
          end
        end
      end
    when 'screenshot'
      uri = URI.parse(driver.current_url)
      path = uri.path
      path += "?#{uri.query}" unless uri.query.nil?
      sc = {
        title: expect['name'].nil? ? path : expect['name'],
        image: driver.screenshot_as(:png)
      }
      screenshot.call sc
    end
  end
end