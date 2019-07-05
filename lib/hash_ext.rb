class Hash
  def symbolize_keys!
    keys.each do |key|
      if key.respond_to? :to_sym
        self[key.to_sym || key] = delete(key)
      end
    end
    self
  end

  def deep_symbolize_keys!
    symbolize_keys!

    values.each do |v|
      case v
      when Hash # symbolize each hash in .values
        v.deep_symbolize_keys! if v.is_a?(Hash)
      when Array # symbolize each hash inside an array in .values
        v.each {|h| h.deep_symbolize_keys! if h.is_a?(Hash) }
      end
    end

    self
  end
end
