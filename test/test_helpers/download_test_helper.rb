# test/test_helpers/download_test_helper.rb
module DownloadTestHelper
  TIMEOUT = 10
  DOWNLOAD_PATH = Rails.root.join("tmp/downloads")

  def downloads
    Dir[DOWNLOAD_PATH.join("*")]
  end

  def download
    downloads.first
  end

  def downloading?
    downloads.grep(/\.crdownload$/).any?
  end

  def downloaded?
    !downloading? && downloads.any?
  end

  def wait_for_download
    Timeout.timeout(TIMEOUT) { sleep 0.1 until downloaded? }
  rescue Timeout::Error
    flunk "No completed download after #{TIMEOUT} seconds. Saw #{downloads.inspect}"
  end

  def clear_downloads
    FileUtils.mkdir_p(DOWNLOAD_PATH)
    FileUtils.rm_f(downloads)
  end
end
