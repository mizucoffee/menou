register_test('db_schema') do |option, test_tb, path|
  table_name = option['table'].classify

  is_not_found = false
  test_tb.task("テーブル'#{table_name}'の存在確認") do |error|
    if !ActiveRecord::Base.connection.tables.include? option['table']
      is_not_found = true
      next error.call 'Table not found'
    end
  end

  next if is_not_found
  columns = ActiveRecord::Base.connection.columns(option['table'])

  option['expect'].each do |col|
    test_tb.task("#{table_name}##{col['name']}の型確認") do |error|
      res = columns.find { |c| c.name == col['name'] }
      next error.call "カラムが存在しません" if res.nil?
      error.call "型が正しくありません", res.type.to_s, col['type'] if col['type'] != res.type.to_s
      unless col['options'].nil?
        col['options'].each do |key, value|
          error.call "オプション'#{key}'の値が正しくありません", res.public_send(key).to_s, value.to_s unless res.public_send(key).to_s == value.to_s
        end
      end
    end
  end
end

register_test('db_where') do |option, test_tb, path|
  test_tb.task("SELECT * FROM #{option['table'].classify} WHERE #{option['where'].map {|k, v| "#{k}=\"#{v}\""}.join ' AND '};") do |error|
    table_class = option['table'].classify.constantize rescue nil
    next error.call "テーブルが存在しません" if table_class.nil?

    result = table_class.find_by(option['where'])
    next if option['expect'].nil? and result.nil?
    next error.call "レコードが存在しません" if result.nil?

    option['expect'].each do |k, v|
      error.call "レコードの値が正しくありません", result[k].to_s, v if result[k].to_s != v.to_s
    end
  end
end
