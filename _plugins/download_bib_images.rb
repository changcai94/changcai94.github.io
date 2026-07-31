require 'jekyll'
require 'bibtex'
require 'open-uri'
require 'nokogiri'
require 'fileutils'

Jekyll::Hooks.register :site, :after_init do |site|
  bib_file = File.join(site.source, '_bibliography', 'papers.bib')
  output_dir = File.join(site.source, 'assets', 'img', 'publication_preview')
  
  next unless File.exist?(bib_file)
  FileUtils.mkdir_p(output_dir)

  # Target formats supported by al-folio
  valid_extensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp']
  bib = BibTeX.open(bib_file)

  bib.each do |entry|
    next unless entry.respond_to?(:key)
    
    key = entry.key.to_s
    # Skip download if an image matching the key already exists
    existing_file = Dir.glob(File.join(output_dir, "#{key}.*")).first
    next if existing_file

    # 1. Check for a direct image URL first
    img_url = entry.respond_to?(:image) ? entry.image.to_s : nil

    # 2. Fallback: Fall back to parsing the main URL field
    if img_url.nil? && entry.respond_to?(:url)
      page_url = entry.url.to_s
      begin
        URI.parse(page_url) # Validate syntax
        doc = Nokogiri::HTML(URI.open(page_url, "User-Agent" => "Mozilla/5.0"))
        
        # Select the first img tag with a valid source attribute
        first_img = doc.css('img').map { |i| i['src'] }.compact.first
        if first_img
          img_url = URI.join(page_url, first_img).to_s
        end
      rescue => e
        Jekyll.logger.warn "BibImage Downloader:", "Could not parse HTML from #{page_url}: #{e.message}"
      end
    end

    # 3. Download and save the image
    if img_url
      begin
        ext = File.extname(URI.parse(img_url).path).downcase
        ext = '.jpg' unless valid_extensions.include?(ext) # Fallback extension
        
        target_path = File.join(output_dir, "#{key}#{ext}")
        
        File.open(target_path, 'wb') do |file|
          file.write(URI.open(img_url, "User-Agent" => "Mozilla/5.0").read)
        end
        Jekyll.logger.info "BibImage Downloader:", "Downloaded image for #{key} -> #{target_path}"
      rescue => e
        Jekyll.logger.warn "BibImage Downloader:", "Failed to download image for #{key}: #{e.message}"
      end
    end
  end
end

