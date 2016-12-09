module API
  # Labels API
  class Labels < Grape::API
    before { authenticate! }

    helpers do
      def filter_issues_state(issues, state)
        case state
        when 'opened' then issues.opened
        when 'closed' then issues.closed
        else issues
        end
      end

      def filter_issues_labels(issues, labels)
        issues.includes(:labels).where('labels.title' => labels.split(','))
      end

      def filter_issues_milestone(issues, milestone)
        issues.includes(:milestone).where('milestones.title' => milestone)
      end
    end


    params do
      requires :id, type: String, desc: 'The ID of a project'
    end
    resource :projects do
      desc 'Get all labels of the project' do
        success Entities::Label
      end
      get ':id/labels' do
        present available_labels, with: Entities::Label, current_user: current_user

        issues = user_project.issues.inc_notes_with_associations.visible_to_user(current_user)
        unless params[:milestone].nil?
          issues = filter_issues_milestone(issues, params[:milestone])
        end

        present :issues, issues, with: Entities::Issue, current_user: current_user
      end

      desc 'Create a new label' do
        success Entities::Label
      end
      params do
        requires :name, type: String, desc: 'The name of the label to be created'
        requires :color, type: String, desc: "The color of the label given in 6-digit hex notation with leading '#' sign (e.g. #FFAABB)"
        optional :description, type: String, desc: 'The description of label to be created'
      end
      post ':id/labels' do
        authorize! :admin_label, user_project

        label = available_labels.find_by(title: params[:name])
        conflict!('Label already exists') if label

        label = user_project.labels.create(declared(params, include_parent_namespaces: false).to_h)

        if label.valid?
          present label, with: Entities::Label, current_user: current_user
        else
          render_validation_error!(label)
        end
      end

      desc 'Delete an existing label' do
        success Entities::Label
      end
      params do
        requires :name, type: String, desc: 'The name of the label to be deleted'
      end
      delete ':id/labels' do
        authorize! :admin_label, user_project

        label = user_project.labels.find_by(title: params[:name])
        not_found!('Label') unless label

        present label.destroy, with: Entities::Label, current_user: current_user
      end

      desc 'Update an existing label. At least one optional parameter is required.' do
        success Entities::Label
      end
      params do
        requires :name,  type: String, desc: 'The name of the label to be updated'
        optional :new_name, type: String, desc: 'The new name of the label'
        optional :color, type: String, desc: "The new color of the label given in 6-digit hex notation with leading '#' sign (e.g. #FFAABB)"
        optional :description, type: String, desc: 'The new description of label'
        at_least_one_of :new_name, :color, :description
      end
      put ':id/labels' do
        authorize! :admin_label, user_project

        label = user_project.labels.find_by(title: params[:name])
        not_found!('Label not found') unless label

        update_params = declared(params,
                                 include_parent_namespaces: false,
                                 include_missing: false).to_h
        # Rename new name to the actual label attribute name
        update_params['name'] = update_params.delete('new_name') if update_params.key?('new_name')

        if label.update(update_params)
          present label, with: Entities::Label, current_user: current_user
        else
          render_validation_error!(label)
        end
      end
    end
  end
end
