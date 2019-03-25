class RakutensController < ApplicationController
    require 'line/bot'

    protect_from_forgery except: [:callback]

    def callback
        body = request.body.read
        signature = request.env['HTTP_X_LINE_SIGNATURE']
        unless client.validate_signature(body, signature)
         head :bad_request
        end
        events = client.parse_events_from(body)
        events.each do |event|
         case event
         when Line::Bot::Event::Message
            case event.type
            when Line::Bot::Event::MessageType::Text 
                input = event.message['text']
                messages = [{"type": "text", "text": "#{input}ですね！こちらはいかがですか？"},
                            search_and_create_message(input),
                            {"type": "text", "text": "よかったらお買い求めください！"}]
                client.reply_message(event['replyToken'], messages)
            end
         end
        end
        head :ok
    end

    private
    def client
        @client ||= Line::Bot::Client.new do |config|
         config.channel_secret = ENV['LINE_CHANNEL_SECRET']
         config.channel_token = ENV['LINE_CHANNEL_TOKEN']
        end
    end

    def search_and_create_message(input)
      RakutenWebService.configure do |c| 
       c.application_id = ENV['RAKUTEN_APPID']
       c.affiliate_id = ENV['REKUTEN_AFID']   
      end
      res = RakutenWebService::Ichiba::Item.search(keyword: input, imageFlag: 1) #このコードで配列が作成されるわけではない？
      #空の配列を作成→rb.40で定義した変数から配列に要素を格納
      items = []
      items = res.map{|item| item}
      item = items.sample
      make_reply_content(item)
     end

    def make_reply_content(item)
        {"type": 'flex',
         "altText": 'This is a Flex Message',
         "contents": 
          { "type": 'carousel',  #bubbleにしていたのが間違い?
            "contents": [
              make_part(item)
            ]
            }
        }
    end

    def make_part(item)
        title = item['itemName']
        price = item['itemPrice'].to_s + "円"
        url = item['itemUrl']
        image = item['smallImageUrls'].first 
        {
          "type": "bubble",
          "hero": {
            "type": "image",
            "size": "full",
            "aspectRatio": "20:13",
            "aspectMode": "cover",
            "url": image
          },
          "body": {
            "type": "box",
            "layout": "vertical",
            "spacing": "sm",
            "contents": [
              {
                "type": "text",
                "text": title,
                "wrap": true,
                "weight": "bold",
                "size": "lg"
              },
              {
                "type": "box",
                "layout": "baseline",
                "contents": [
                  {
                    "type": "text",
                    "text": price,
                    "wrap": true,
                    "weight": "bold",
                    #"size": "xl",
                    "flex": 0
                  }
                ]
              }
            ]
          },
          "footer": {
            "type": "box",
            "layout": "vertical",
            "spacing": "sm",
            "contents": [
              {
                "type": "button",
                "style": "primary",
                "action": {
                  "type": "uri",
                  "label": "商品ページへ",
                  "uri": url
                }
              }
            ]
          }
        }
    end
end
