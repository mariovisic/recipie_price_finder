require 'nokogiri'
require 'ostruct'

class Recipe < OpenStruct
end

class IngredientItem < OpenStruct
  def to_s
    if quantity_unit
      "#{UNITS[quantity_unit][:to_s] % quantity} #{name}"
    end
  end
end

UNITS = {
  :table_spoon => {
    regexp: /(\d+)\s*tbsp\s/i,
    to_s: "%s tbsp"
  },
  :tea_spoon => {
    regexp: /(\d+)\s*tsp\s/i,
    to_s: "%s tsp"
  },
  :grams => {
    regexp: /(\d+)\s*g\s/,
    to_s: "%sg"
  },
  :millilitres => {
    regexp: /(\d+)\s*ml\s/,
    to_s: "%sml"
  },
  :none => {
    regexp: /(\d+)/,
    to_s: "%s x"
  }
}

class RecipieParser
  def self.parse(file)
    file.respond_to?(:read) ? new(file.read).parse : new(file).parse
  end

  def initialize(html)
    @document = Nokogiri::HTML(html)
  end
  private_class_method :new

  def parse
    rec = Recipe.new(ingredient_items: []).tap do |recipie|
      ingredient_elements.each do |ingredient_element|
        recipie.ingredient_items.push(IngredientItemParser.parse(ingredient_element))
      end
    end
  end

  private

  def ingredient_elements
    @document.xpath('//li[contains(@class, "ingredient")]')
  end
end

class IngredientItemParser
  def self.parse(html_element)
    new(html_element).parse
  end

  def initialize(html_element)
    @html_element = html_element
  end

  def parse
    IngredientItem.new(element: @html_element, quantity: quantity, quantity_unit: quantity_unit, name: name)
  end

  private

  def name
    name_match
  end

  def quantity
    quantity_match && quantity_match[:quantity]
  end

  def quantity_unit
    quantity_match && quantity_match[:unit]
  end

  def lines
    @lines ||= @html_element.children.map(&:text).join("\n").lines
  end

  def name_match
    if quantity_match
      @name_match ||= begin
        quantity_line_with_quantity_removed = lines[quantity_match[:index]].gsub(quantity_match[:match], '').strip
        if !quantity_line_with_quantity_removed.empty?
          quantity_line_with_quantity_removed.capitalize
        else
          lines[quantity_match[:index] + 1].capitalize
        end
      end
    end
  end

  def quantity_match
    @quantity_match ||= lines.each_with_index do |line, index|
      UNITS.each do |unit, unit_info|
        if match = line.match(unit_info[:regexp])
          return { match: match[0], quantity: match[1].to_i, unit: unit, index: index }
        end
      end
    end
    nil
  end
end
