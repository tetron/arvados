class VirtualMachine < ArvadosBase
  attr_accessor :current_user_logins
  def self.creatable?
    current_user.andand.is_admin
  end
  def attributes_for_display
    logger.debug super.append ['current_user_logins', @current_user_logins]
    super.append ['current_user_logins', @current_user_logins]
  end
  def attribute_editable?(attr)
    attr != 'current_user_logins' and super
  end
  def self.attribute_info
    merger = ->(k,a,b) { a.merge(b, &merger) }
    merger [nil,
            {current_user_logins: {column_heading: "logins", type: 'array'}},
            super]
  end
end
