# typed: false
# frozen_string_literal: true

# Authorization for Client self-service records on the app surface.
# Registration, withdrawal, and org support use their own explicit boundaries.
class ClientPolicy < ApplicationPolicy
  public
  def index? = false

  def show? = user.is_a?(::Client) && owner?

  def create? = false

  def update? = user.is_a?(::Client) && owner?

  # Account withdrawal is governed by ClientWithdrawalPolicy.
  def destroy? = false

  relation_scope do |relation|
    user.is_a?(::Client) ? relation.where(id: user.id) : relation.none
  end
end
