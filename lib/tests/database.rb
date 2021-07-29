register_test('db_schema') do |option, test_tb, path|
  table_name = option['table'].classify

  test_tb.task("テーブル \"#{table_name}\" の存在確認") do |error|
    if !ActiveRecord::Base.connection.tables.include? option['table']
      next error.call 'Table not found'
    end
  end

  columns = ActiveRecord::Base.connection.columns(option['table'])

  option['expect'].each do |col|
    test_tb.task("#{table_name}##{col['name']}の型確認") do |error|
      res = columns.find { |c| c.name == col['name'] }
      next error.call "カラムが存在しません" if res.nil?
      error.call "型が正しくありません 結果: '#{res.type.to_s}' 期待する値: '#{col['type']}'" if col['type'] != res.type.to_s
      unless col['options'].nil?
        col['options'].each do |key, value|
          error.call "オプション'#{key}'の値が正しくありません 結果: '#{res.public_send(key).to_s}' 期待する値: '#{value.to_s}'" unless res.public_send(key).to_s == value.to_s
        end
      end
    end
  end
end

# register_test('db_select') do |option, test_tb, path|
#   test_tb.task("Database #{task['table'].classify} where: #{task['where'].map {|k, v| "#{k}=\"#{v}\""}.join ', '}") do |success, error|
#     table_class = task['table'].classify.constantize rescue nil
#     next error.call "Table not found" if table_class.nil?

#     result = table_class.find_by(task['where'])
#     next success.call if task['expect'].nil? and result.nil?
#     next error.call "Record not found" if result.nil?

#     task['expect'].each do |k, v|
#       error.call "Unexpected value: #{task['table'].classify}.#{k}=\"#{result[k]}\", expected: \"#{v}\"" if result[k].to_s != v.to_s
#     end
#   end
# end