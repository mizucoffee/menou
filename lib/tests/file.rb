require 'digest'

register_test('file_exists') do |option, test_tb, path, driver|
  option['files'].each do |file|
    test_tb.task(file) do |error|
      error.call "'#{file}'が見つかりません" unless Dir[File.expand_path(file, path)].any?
    end
  end
end

register_test('file_hash') do |option, test_tb, path, driver|
  option['files'].each_with_index do |file, idx|
    test_tb.task(file) do |error|
      next error.call "'#{file}'が見つかりません" unless File.exist?(File.expand_path(file, path))
      digest = Digest::SHA256.file(File.expand_path(file, path)).hexdigest
      error.call "'#{file}'のハッシュ値が合致しません", digest, option['expect'][idx] unless option['expect'][idx] == digest
    end
  end
end
