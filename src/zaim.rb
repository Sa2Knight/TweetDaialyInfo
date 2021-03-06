require 'oauth'
require 'json'
require 'pp'
require_relative 'util'
class Zaim

  MONTHLY_BUDGET  = 60000
  API_URL          = 'https://api.zaim.net/v2/'.freeze
  LUNCH_GENRE_ID   = 10104
  HAIRCUT_GENRE_ID = 11105

  #
  # 初期化時にZaimAPIの利用準備を行う
  #
  def initialize(date)
    api_key = Util.get_zaim_api_key
    oauth_params = {
      site: "https://api.zaim.net",
      request_token_path: "/v2/auth/request",
      authorize_url: "https://auth.zaim.net/users/auth",
      access_token_path: "https://api.zaim.net"
    }
    @consumer = OAuth::Consumer.new(api_key["key"], api_key["secret"], oauth_params)
    @access_token = OAuth::AccessToken.new(@consumer, api_key["access_token"], api_key["access_token_secret"])
    @date = date
    @payments_cach = {}
  end

  #
  # 本日のお昼を食べた場所を戻す
  #
  def get_lunch_place
    payments = get_days_payments(@date, genre_id: LUNCH_GENRE_ID)
    return '支払い情報なし' if payments.nil? || payments.first.nil?

    payment = payments.first
    return '店舗情報なし' if payment['place'].nil? || payment['place'].empty?

    return payment['place']
  end

  #
  # 前回散髪からの日数を戻す
  #
  def get_days_since_hair_cut
    payments = get_payments(genre_id: HAIRCUT_GENRE_ID)
    last_date = Date.parse(payments.first['date'])
    (@date - last_date).to_i
  end

  #
  # 本日の私費/公費の和をそれぞれ戻す
  #
  def get_days_amount(params = {})
    payments = get_days_payments(@date, params)
    private_payments = payments.select{|payment| payment['comment'] =~ /私費/}
    public_payments  = payments.select{|payment| payment['comment'] =~ /公費/}
    unless (payments - private_payments - public_payments).empty?
      raise '公費でも私費でもない支払いがzaimに登録されてるよ！'
    end
    public_amounts = public_payments.inject(0) {|sum, n| sum + n['amount'] }
    private_amounts = private_payments.inject(0) {|sum, n| sum + n['amount'] }
    return {
      public: public_amounts,
      private: private_amounts
    }
  end

  #
  # 今月の残りお小遣い額を取得
  #
  def get_current_month_private_budget
    payments = get_month_payments(@date.year, @date.month).select {|payment| payment['comment'] =~ /私費/}
    total_amount = payments.inject(0) {|sum, n| sum + n['amount']}
    return MONTHLY_BUDGET - total_amount
  end

  #
  # 今月の残りお小遣い額の目安を取得
  # ex) 今月残り1/3の場合、お小遣い額の2/3を戻す
  #
  def get_month_private_budget_indication
    days_rate = Util.days_rate_by(date: @date)
    (MONTHLY_BUDGET * (1 - days_rate)).to_i
  end

  private

    #
    # 指定した日付の支出一覧を取得
    #
    def get_days_payments(date, params = {})
      date = date.strftime('%Y-%m-%d')
      get_payments(params.merge({
        start_date: date,
        end_date:   date
      }))
    end

    #
    # 指定した月の支出一覧を取得
    #
    def get_month_payments(year, month, params = {})
      get_payments({
        start_date: Date.new(year, month),
        end_date:   Date.new(year, month, -1)
      })
    end

    #
    # 支出一覧を取得
    # 同パラメータの場合はキャッシュを用いる
    #
    def get_payments(params)
      cach_key = params.to_s
      return @payments_cach[cach_key] if @payments_cach[cach_key]

      params.merge!({
        'mode': 'payment'
      })
      url = Util.make_url("home/money" , params)
      @payments_cach[cach_key] = get(url)['money']
    end

    #
    # ZaimAPIに対してPOSTリクエストを送信
    #
    def get(url)
      response = @access_token.get("#{API_URL}#{url}")
      JSON.parse(response.body)
    end
end
