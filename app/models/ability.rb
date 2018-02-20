class Ability
  include CanCan::Ability

  def initialize(user)
    # Define abilities for the passed in user here. For example:
    #
    #   user ||= User.new # guest user (not logged in)
    #   if user.admin?
    #     can :manage, :all
    #   else
    #     can :read, :all
    #   end
    #
    # The first argument to `can` is the action you are giving the user
    # permission to do.
    # If you pass :manage it will apply to every action. Other common actions
    # here are :read, :create, :update and :destroy.
    #
    # The second argument is the resource the user can perform the action on.
    # If you pass :all it will apply to every resource. Otherwise pass a Ruby
    # class of the resource.
    #
    # The third argument is an optional hash of conditions to further filter the
    # objects.
    # For example, here the user can only update published articles.
    #
    #   can :update, Article, :published => true
    #
    # See the wiki for details:
    # https://github.com/CanCanCommunity/cancancan/wiki/Defining-Abilities

    # Allow read access non-private
    can :read, Project, private: false
    can :read, [App, Branch, Issue, Release, MergeRequest], project: {private: false}
    can :read, [Build, Test], branch: {project: {private: false}}

    if user.present?
      # Always performed
      # can :access, :rails_admin # needed to access RailsAdmin
      # can :dashboard
      # can :read, :all
      # can :export, :all
      # can :history, :all # for HistoryIndex

      can :read, Project, member_ids: user.id
      can :master, Project, master_ids: user.id

      can :read, [App, Branch, Issue, Release, MergeRequest], project: {member_ids: user.id}
      can :read, [Build, Test], branch: {project: {member_ids: user.id}}

      can [:create, :update, :destroy], [Build, Test], branch: {protected: false, project: {member_ids: user.id}}
      can [:create, :update, :destroy], [Build, Test], branch: {protected: true, project: {master_ids: user.id}}

      can :update, App, stage: App.stage.values.first, project: {member_ids: user.id}
      can :update, App, project: {master_ids: user.id}

      can :update, MergeRequest, project: {master_ids: user.id}

      can [:create, :update], Release, project: {master_ids: user.id}

      if user.admin?
        can :manage, :all
      end
    end
  end
end
