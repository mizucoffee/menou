client = Faraday.new 'http://localhost:4567' do |b|
  b.use :cookie_jar
  b.adapter Faraday.default_adapter
end

def full_url(path, query)
  "#{path}?#{(query.nil?) ? "" : URI.encode_www_form(query)}"
end

register_test('http_get_status') do |option, test_tb, path, driver|
  url = full_url(option['path'], option['query'])

  test_tb.task("GET #{option['path']}") do |error|
    res = client.get url
    error.call "ステータスコードが正しくありません", res.status, option['expect'] if res.status != option['expect']
  end
end

register_test('http_get_json') do |option, test_tb, path, driver|
  url = full_url(option['path'], option['query'])

  test_tb.task("GET #{option['path']} as JSON API") do |error|
    res = client.get url
    json = JSON.parse(res.body) rescue nil
    next error.call "JSON形式ではありません" if json.nil?

    option['expect'].each do |k, v|
      error.call "'#{k}'の値が正しくありません", json[k], v if v != json[k]
    end
  end
end

register_test('http_post_status') do |option, test_tb, path, driver|
  url = full_url(option['path'], option['query'])

  test_tb.task("POST #{option['path']}") do |error|
    res = client.post(url) do |req|
      req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
      req.body = URI.encode_www_form option['body'] unless option['body'].nil?
    end
    error.call "ステータスコードが正しくありません", res.status, option['expect'] if res.status != option['expect']
  end
end

register_test('http_post_json') do |option, test_tb, path, driver|
  url = full_url(option['path'], option['query'])

  test_tb.task("POST #{option['path']} as JSON API") do |error|
    res = client.post(url) do |req|
      req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
      req.body = URI.encode_www_form option['body']
    end
    json = JSON.parse(res.body) rescue nil
    next error.call "JSON形式ではありません" if json.nil?

    option['expect'].each do |k, v|
      error.call "'#{k}'の値が正しくありません", json[k], v if v != json[k]
    end
  end
end
