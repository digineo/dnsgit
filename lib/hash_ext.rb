class Hash
  def symbolize_keys!
    keys.each do |key|
      self[(key.to_sym rescue key) || key] = delete(key)
    end
    self
  end
  
  def deep_symbolize_keys!
    symbolize_keys!
    # symbolize each hash in .values
    values.each{|h| h.deep_symbolize_keys! if h.is_a?(Hash) }
    # symbolize each hash inside an array in .values
    values.select{|v| v.is_a?(Array) }.flatten.each{|h| h.deep_symbolize_keys! if h.is_a?(Hash) }
    self
  end
end