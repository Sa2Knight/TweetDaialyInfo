require_relative 'twitter'
require_relative 'zaim'
today = Date.today.strftime("%Y-%m-%d")
todays_amount = Zaim.new.get_days_amount(today)
Twitter.new.tweet("本日(#{today})の支出額は#{todays_amount}円です。 #ketilog")
