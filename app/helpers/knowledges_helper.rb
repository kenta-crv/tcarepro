module KnowledgesHelper
    def embed_video(video_url)
        youtube_id = extract_youtube_id(video_url)
        content_tag(:iframe, nil, src: "//www.youtube.com/embed/#{youtube_id}", width: 500, height: 300, frameborder: 0, allowfullscreen: true)
      end
    
      def extract_youtube_id(video_url)
        regex = /(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})/
        match = video_url.match(regex)
        match[1] if match && match[1]
      end
end
