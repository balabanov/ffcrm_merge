module MergeHelper

  def link_to_new_window(text, path)
    link_to(text, path, :target => "_blank")
  end

  # Generates a radio button for selecting which attributes
  # to ignore from the duplicate contact.
  # --------------------------------------------------------
  def ignore_merge_radio_button(value, attribute, merge_case)
    case merge_case
    when :master
      checked = value == "yes" ? {:checked => "checked"} : {}
    when :duplicate
      checked = value == "no"  ? {:checked => "checked"} : {}
    end

    tag(:input, {
      :type  => "radio",
      :name  => "ignore[_self][#{attribute}]",
      :id    => "ignore_self_#{attribute}_#{value}",
      :value => value
    }.merge(checked))
  end

  # Returns a hash with default merge attributes for radio buttons.
  # (master contact is default)
  # --------------------------------------------------------
  def calculate_default_merge(duplicate_attr, master_attr)
    merge = {}
    duplicate_attr.each do |attribute, dup_value|
      master_value = master_attr[attribute]
      if not master_value.blank?
        merge[attribute] = :master
      elsif not dup_value.blank?
        merge[attribute] = :duplicate
      end
    end
    merge
  end


  # Merge attributes for custom fields
  # --------------------------------------------------------
  # Transforms the list of merge attributes into a display
  # format (ie, with links / model associations), to be
  # displayed in the merge selection table.
  # --------------------------------------------------------
  def custom_field_merge_attributes(field_group, object, html = true)
    custom_fields = field_group.fields.sort_by(&:position)
    custom_fields.inject({}){ |hash, field| hash[field.name] = field.render_value(object); hash }
  end

end
