module AffiliateCredits
  private

  def create_affiliate_credits(sender, recipient, event)
    #check if sender should receive credit on affiliate register
    if sender_credit_amount = SpreeAffiliate::Config["sender_credit_on_#{event}_amount".to_sym] and sender_credit_amount.to_f > 0
      credit = Spree::StoreCredit.create({:amount => sender_credit_amount,
                         :remaining_amount => sender_credit_amount,
                         :reason => "Affiliate: #{event} reward to sender", :user => sender}, :without_protection => true)
      RafCreditNoticeJob.perform_async sender.id, recipient.id, event.to_sym
      log_event recipient.affiliate_partner, sender, credit, event
    end if sender


    #check if affiliate should recevied credit on sign up
    if recipient_credit_amount = SpreeAffiliate::Config["recipient_credit_on_#{event}_amount".to_sym] and recipient_credit_amount.to_f > 0
      credit = Spree::StoreCredit.create({:amount => recipient_credit_amount,
                         :remaining_amount => recipient_credit_amount,
                         :reason => "Affiliate: #{event}", :user => recipient}, :without_protection => true)

      log_event recipient.affiliate_partner, recipient, credit, event
    end if recipient

  end
  
  def create_register_affiliate_credits(sender, recipient, event)
    create_affiliate_credits(sender.has_invited ? nil : sender, recipient, event)
  end
  
  def create_first_order_affiliate_credits(sender, recipient, event)
    create_affiliate_credits(sender, recipient, event)
  end

  def log_event(affiliate, user, credit, event)
    affiliate.events.create({:reward => credit, :name => event, :user => user}, :without_protection => true)
  end

  def check_affiliate(user)
    return if cookies[:ref_id].blank? || user.nil? || user.invalid?
    sender = Spree::User.find_by_ref_id(cookies[:ref_id])

    if sender && sender.id != user.id
      affiliate = sender.affiliates.build(:user_id => user.id)
      return unless affiliate.save
      #create credit (if required)
      create_register_affiliate_credits(sender, user, "register")
      sender.update_attributes(has_invited: true)
    end

    #destroy the cookie, as the affiliate record has been created.
    cookies[:ref_id] = nil
  end

end
