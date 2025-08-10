class Security::ComboboxOption
  include ActiveModel::Model

  attr_accessor :symbol, :name, :logo_url, :exchange_operating_mic, :country_code

  def id
    "#{symbol}|#{exchange_operating_mic}"
  end

  def to_combobox_display
    "#{symbol} - #{name} (#{exchange_operating_mic})"
  end
end
