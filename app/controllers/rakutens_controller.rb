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
                message = search_and_create_message(input)
                client.reply_message(event['replyToken'], message)
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
      items = RakutenWebService::Ichiba::Item.search(keyword: input, imageFlag: 1, hasReviewFlag: 1)
      #検索結果が0だったときの処理が分からない.エラーを返した時とそれ以外で条件分岐？
      if items['count'] == 0
        return "#{input}では見つかりませんでした。"
      else
        item = items.sort_by{rand}[0,1].first
        return [{type: 'text', text: '#{input}ですね！' + "\n" + 'こんなものはいかがですか？'},
                 make_reply_content(item) ,
                {type: 'text', text: '良かったらお買い求めください！'}]
        #make_reply_content(item)
      end
     end

    def make_reply_content(item)
        {"type": 'flex',
         "altText": 'This is a Flex Message',
         "contents": 
          { "type": 'bubble',
            "contents":[   
              #ここはfor文ではダメなのか？試してみたらエラーは吐かなかったが作動しなかった.
              make_part(item)
          ]}
        }
    end

    def make_part(item)
        title = item['itemName']
        price = item['itemPrice'].to_s + "円"
        url = item['itemUrl']
        image = item['mediumImageUrls'].first 
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
