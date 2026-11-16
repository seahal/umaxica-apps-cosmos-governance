# typed: false
# frozen_string_literal: true

class ClientPasskeyPolicy < ApplicationPolicy
  public

  def index?
    user.present?
  end

  def show?
    owner?
  end

  def create?
    user.present?
  end

  def new?
    create?
  end

  def update?
    owner?
  end

  def edit?
    update?
  end

  def destroy?
    owner?
  end

  relation_scope do |relation|
    return relation.none unless user

    relation.where(user_id: user.id)
  end
  def management_requirement(token:)
    raise AccessOpDataUnavailableError
  end

  def management_authorized?(token:, now:)
    raise AccessOpDataUnavailableError
  end
end
