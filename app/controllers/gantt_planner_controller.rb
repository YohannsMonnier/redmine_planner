# redMine - project management software
# Copyright (C) 2006-2007  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.



#############################################
#  IMPORTATION OF PROJECTS FROM XML         #
#############################################
#
# Yohann Monnier - Internethic 
# http://www.internethic.com
#
#
# SHAPE OF THE XML FILE
# ----------------------
# see the model planner file
##############################################

require 'active_record'
require 'iconv'
require 'pp'
require 'enumerator'

class GanttPlannerController < ApplicationController
	unloadable

	# Manage authorization
	before_filter :require_admin, :get_mysettings
  	layout 'base'
  	helper :issues
  	helper :projects
  	helper :trackers
  	helper :users
  
  	mattr_reader :issue_xml
  	
	# Set priorities
	priorities = IssuePriority.all
	DEFAULT_PRIORITY = priorities[0]
	PRIORITY_MAPPING = {'lowest' => priorities[0],
						'low' => priorities[0],
						'medium' => priorities[1],
						'high' => priorities[2],
						'critical' => priorities[3]
						}
	# Set statuses
	DEFAULT_STATUS = IssueStatus.default
	assigned_status = IssueStatus.find_by_position(2)
	resolved_status = IssueStatus.find_by_position(3)
	feedback_status = IssueStatus.find_by_position(4)
	closed_status = IssueStatus.find :first, :conditions => { :is_closed => true }
	STATUS_MAPPING = {'open' => DEFAULT_STATUS,
					  'reopened' => feedback_status,
					  'resolved' => resolved_status,
					  'in progress' => assigned_status,
					  'closed' => closed_status
					 }
	# Set tracker 
	TRACKER_BUG = Tracker.find_by_position(2)
	TRACKER_FEATURE = Tracker.find_by_position(3)
	TRACKER_TASK = Tracker.find_by_position(6)
	ODEFAULT_TRACKER = 	TRACKER_BUG
	TRACKER_MAPPING = {	
											'bug' => TRACKER_BUG,
											'enhancement' => TRACKER_FEATURE,
											'task' => TRACKER_TASK,
											'new feature' =>TRACKER_FEATURE
										}

	# Data shared by methods
	@@migrated_projects = 0
	@@migrated_issues = 0
	@@migrated_deliverables = 0
	
	@@strNoticeMessage = ""
	@@strWarningMessage = ""
	@@strErrorMessage = ""
	
	@xml_a_afficher =""
	
	customer_identifier =0
	deliverable_identifier = 0
	projet = ""
	task_identifier = ""
	task_ressources = ""
  	
  	# When I load Index page
  	#-----------------------
  	def index
  
  	end
  
   	# When I load xml
  	#-----------------------
  	def planner
  
  	end

	# When I load Import page, doing the importation
	#-----------------------------------------------
	def import
  		# @attachment = params[:attachments]
  		myFileXML = params[:attachments]["1"]["file"]
  		myFileXML.rewind
  		# initializing default values from settings
  		@@DEFAULT_ROLE = Role.find_by_id(@settings['importer_role_id'].to_i())
  		@@allroles = Role.find(:all, :conditions => {:builtin => 0}, :order => 'position ASC')
			@@DEFAULT_TRACKER =  Tracker.find_by_id(@settings['importer_tracker_id'].to_i())
			@@priorities_mapping = IssuePriority.all
			@@DEFAULT_PRIORITY = @@priorities_mapping[@settings['importer_priority_id'].to_i()-3]
			@@issue_xml = myFileXML.read
		
			## Save a hash whom keys are name of tracker and value their id.
			@@allTrackers = Hash.new("empty")
			@@allTrackersCollection = Tracker.all
			@@allTrackersCollection.each do |tracker|
				@@allTrackers[tracker.name] = tracker
			end
		
			## appel à la fonction de migration
			migrate_planner
		
			@@strWarningMessage = 	"
															#{@@migrated_projects} #{l(:created_projects)}<br />
															#{@@migrated_deliverables} #{l(:created_deliverables)}<br />
															#{@@migrated_issues} #{l(:created_issues)}<br />
															"
		
			if (@@strNoticeMessage !="") 
				flash.now[:notice]=  "<div onclick='javascript:showAndScrollTo(\"monnouveauplanner\")'>Afficher le nouveau XML</div>
									 						<div id='monnouveauplanner' style='display:none;'>#{@@output_string}</div>"
			end
			if (@@strWarningMessage !="") 
				flash.now[:warning]= "#{@@strWarningMessage}<br /><br />#{@@strNoticeMessage}"
								
			end
			if (@@strErrorMessage !="") 
				flash.now[:error]= @@strErrorMessage
			end

  end
  	
	def migrate_planner
			doc = REXML::Document.new @@issue_xml
			myTasks = Hash.new("empty")
			myProjects = Hash.new("empty")
			myRessources = Hash.new("empty")
			# loading projects in an array
			doc.elements.each('project/tasks/task') do |customer|
				int_indice_tab = (customer.attributes["id"])
				myProjects[int_indice_tab] = customer
			end
			
			# loading all ressources
			@@role_of_projectManager = nil
			@@price_per_hour_of_projectManager = nil
			doc.elements.each('project/resources/resource') do |ressource|
				int_indice_tab = (ressource.attributes["id"])
				myRessources[int_indice_tab] = ressource
				#				if ressource.attributes["name"] == @@projectManager
				#					for dataGroup in doc.elements.to_a("project/resource-groups/group[@id='#{ressource.attributes['group']}']")
				#						# save group for Project Manager
				#						@@role_of_projectManager  = dataGroup.attributes['name']
				#					end
				#					# save price per hour for the project manager
				#					@@price_per_hour_of_projectManager = ressource.attributes["std-rate"]
				#				end 
			end
			# Initialize iterator (waiting for id from OpenERP for real Ids)
			int_j = 0
			int_i = 0
			# Begin Parsing XML
			myProjects.each do |idx , dataCustomer|
				# iterated name
				int_j = int_j+1
			    # iterated name
			    customerstring = "cl" + int_j.to_s()
			    	# Import Factory to create the customer
			    		# Get the identifier
			    		@customer_identifier =0
			    		# looking for the redmine identifier
			    		dataCustomer.elements.each("properties/property[@name='redmine']") do |redmineLine|
			    			@customer_identifier = redmineLine.attributes['value'].to_i()
			    		end
			    		# Call to Import Factory
#			    		manage_customer(@customer_identifier, dataCustomer)
			    		# Save the id of the customer in the XML file
#			    		dataCustomer.elements.each("properties/property[@name='redmine']") do |redmineLine|
#			    			redmineLine.attributes['value'] = @customer_identifier.to_s()
#			    		end
			    # Manage the projects
			    dataCustomer.elements.each('task') do |dataProject|
			    	int_i = int_i+1
			   		# Import Factory to create the project
			   			# Get the identifier
			   			#project_identifier = customerstring+"_proj"+int_i.to_s()
			   			#project_identifier = "proj"+int_i.to_s()
			   			project_identifier = dataProject.attributes['note'].gsub('_', '-')
			   			# Call to Import Factory
			   			manage_project(project_identifier, dataProject, @customer_identifier)
			   			# Save the id of the project in the XML file
			    		##dataProject.elements.each("properties/property[@name='redmine']") do |redmineLine|
			    			##redmineLine.attributes['value'] = project_identifier.to_s()
			    		##end
			   			for_task_project = project_identifier
			   			# looking for this project using this identifier
						project_loaded = Project.find_by_identifier(for_task_project)
						if project_loaded
							# Manage the deliverables
							dataProject.elements.each('task') do |dataDeliverable|
								@deliverable_identifier = 0
								# looking for the redmine identifier
			    				dataDeliverable.elements.each("properties/property[@name='redmine']") do |redmineLine|
			    					@deliverable_identifier = redmineLine.attributes['value'].to_i()
			    				end
								# initialize task predecessor
								task_predecessor = []
								# initialize task ressources
								task_ressources = []
								# Call to Import Factory
								manage_deliverable(@deliverable_identifier,dataDeliverable,  for_task_project)
								# Save the id of the deliverable in the XML file
								dataDeliverable.elements.each("properties/property[@name='redmine']") do |redmineLine|
									redmineLine.attributes['value'] = @deliverable_identifier.to_s()
								end
								dataDeliverable.elements.each('task') do |dataTask|
									# We look to all informations before import the task
									@task_identifier = 0
									# looking for the redmine identifier
									dataTask.elements.each("properties/property[@name='redmine']") do |redmineLine|
										@task_identifier = redmineLine.attributes['value'].to_i()
									end
									# Call to Import Factory
									manage_task(@task_identifier, dataTask,   project_identifier , @deliverable_identifier)
									myTasks[dataTask.attributes['id']] = @task_identifier
									dataTask.elements.each("properties/property[@name='redmine']") do |redmineLine|
										redmineLine.attributes['value'] = @task_identifier.to_s()
									end
										# ressources
										for dataRessource in doc.elements.to_a("project/allocations/allocation[@task-id='#{dataTask.attributes['id']}']")
											# I save ressources of the task
											task_ressources << dataRessource.attributes['resource-id']
											# initialize role
											role_per_group_data =""
											# looking for the assigned role
											for dataGroup in doc.elements.to_a("project/resource-groups/group[@id='#{myRessources[dataRessource.attributes['resource-id']].attributes['group']}']")
												# save group
												role_per_group_data = dataGroup.attributes['name']
											end
											# save Price per hour
											price_per_hour = myRessources[dataRessource.attributes['resource-id']].attributes['std-rate']												
											# assign an user to the task
											add_assigned_user(@task_identifier, myRessources[dataRessource.attributes['resource-id']].attributes['name'], project_identifier,role_per_group_data,price_per_hour )
										end

								end
							end
							# Managin predecessor for All tasks of this project
							dataProject.elements.each('task/task') do |dataTask|
								dataTask.elements.each('predecessors/predecessor') do |predecessor_task|
									# predecessors
									predecessor_id = predecessor_task.attributes['predecessor-id']
									# defining current task
									@task_identifier = myTasks[dataTask.attributes['id']]
									for dataPredecessor in doc.elements.to_a("project/tasks/task/task/task/task[@id='#{predecessor_id}']") #[@id='#{predecessor_id}']
										# add a predecessor task
										add_predecessor_task(@task_identifier, myTasks[dataPredecessor.attributes['id']])
									end
								end
							end
						end
			   	end
			end
		## write new version of xml document
		#@@output_string =""  :type => 'application/pdf',
		@@output_string ="" 	## doc.to_s.gsub( '<', "&lt;" ).gsub( '>', "&gt;").gsub( "\n" , "<br />")
		send_data(doc.to_s(), :filename => "monplanning.planner")
		#render :GanttImporterController =>  doc.to_s.to_xml
	end  	
  	

  	# Create or update a customer (if necessary)
	def manage_customer(identifier, dataCustomer)
		customer = Customer.find_by_id(identifier)
		if customer.nil?
			# New record
			customer = Customer.create(	:name => dataCustomer.attributes['name'].humanize, 
																	:company => dataCustomer.attributes['name'].humanize)		
			# recording Factory Reports
			if (customer)
				@@strNoticeMessage << "<b>Import Factory : 1 #{l(:customer_has_been_created)} : '#{dataCustomer.attributes['name']}'.</b><br />"
			else
				@@strErrorMessage << "#{l(:unable_to_create_customer)} : '#{dataCustomer.attributes['name']}'!<br />"
			end
		else
				@@strNoticeMessage << "<b>Import Factory : the Customer : '#{dataCustomer.attributes['name']}' already exists.</b><br />"
		end

		@customer_identifier = customer.id
	end
		
  	# Create or update a project (if necessary)
	def manage_project(identifier, dataProject, customer_identifier)
		# looking for an existing project using this identifier
		project = Project.find_by_identifier(identifier)
		# currently, I do not update projects.. yet
		if !project
			# create the target project
			project = Project.new :name => dataProject.attributes['name'].humanize,
								  :description => "Description indisponible",
								  :is_public => 0
			# we don't manage parent project option currently but we could
			## project.parent_id = @target_project.id
			# assigning project to customer
			##project.customer_id = customer_identifier
			# assigning an identifier to the project
			project.identifier = identifier
			# Saving the new project
			if (project.save)
				@@strNoticeMessage << "<b>---Import Factory : 1 Project has been created : '#{identifier}'.</b><br />"
				# Update number of migrated projects
				@@migrated_projects += 1
			else
				@@strErrorMessage << "Unable to create a project with identifier '#{identifier}' and name : '#{dataProject.attributes['name']}'!<br />
									  Importation of all data belonging to this project has been aborted ! <br /> "
			end
			# enable modules for the created project
			project.enabled_module_names = ['issue_tracking','customer_module','budget_module','wiki']
			@@allTrackersCollection.each do |tracker|
				project.trackers << tracker
			end
			# record the instance
			@project = project
		end
	end
	
  	# Create or update a deliverable (if necessary)
	def manage_deliverable(identifier,dataDeliverable, project_identifier)
		# looking for the existing project using this identifier
		project = Project.find_by_identifier(project_identifier)
			if project
				# looking for an existing deliverable
				deliverable = Deliverable.find_by_id(identifier)
				# RECHERCHE DE LA PROPRIETE BUDGET
				cost = get_property(dataDeliverable, "properties/property", "budget")
				if !deliverable
					# create the target deliverable
					deliverable = FixedDeliverable.new({:subject => dataDeliverable.attributes['name'] })
					# setting budget
					deliverable.fixed_cost = cost
					# assigning derivable to the project
					deliverable.project = project
					# It seemed to be usefull, but I didn't guess how
					#budget = Budget.new(project.id)
					if (deliverable.save)
						@@strNoticeMessage << "<b>------Import Factory : 1 #{l(:deliverable_has_been_created)} : '#{deliverable.subject}'.</b><br />"
						# Update number of migrated deliverables
						@@migrated_deliverables += 1
					else
						@@strErrorMessage << "Unable to create a deliverable !<br />"
					end
				else
					# update datas of the deliverable
					deliverable.subject = dataDeliverable.attributes['name']
					deliverable.fixed_cost = cost
					if (deliverable.save)
						@@strNoticeMessage << "<b>------Import Factory : the Deliverable : '#{deliverable.subject}' already exists and has been updated.</b><br />"
						# Update number of migrated deliverables
						@@migrated_deliverables += 1
					else
						@@strErrorMessage << "Unable to update an existing deliverable !<br />"
					end
				end
				# I save the deliverable id
				@deliverable_identifier = deliverable.id
			end
	end
		
  	# Create or update a task (if necessary)
	def manage_task(task_identifier, dataTask , project_identifier, deliverable_identifier)
		# looking for the existing project using this identifier
		aProject = Project.find_by_identifier(project_identifier)
		# number of estimated hours
		estimated_hours = (dataTask.attributes['work'].to_i())/3600
		int_estimated_hours = estimated_hours.to_i()
		str_estimated_hours = int_estimated_hours.to_s()
		# Priority of the task
		task_priority =@@DEFAULT_PRIORITY unless task_priority = @@priorities_mapping[dataTask.attributes['priority'].to_i()]
		# finding tracker attribute
		task_tracker = get_property(dataTask, "properties/property", "tracker")
		# if the found tracker exists, it is assigned, else, we assigned the default tracker
		tracker_to_be_assign = @@DEFAULT_TRACKER			
		@@allTrackersCollection.each do |tracker|
			if task_tracker == tracker.name
				tracker_to_be_assign = tracker
			end
		end
		# If I can find the project
		if aProject
			i = Issue.find_by_id(task_identifier)
			if !i
				i = Issue.new 				:project => aProject,
											:subject => encode(dataTask.attributes['name'][0, limit_for(Issue, 'subject')]),
											:description => encode(dataTask.attributes['name'][0, limit_for(Issue, 'subject')]), 
											:priority => task_priority,
											:created_on => Time.parse(dataTask.attributes['work-start']),
											:updated_on => Time.parse(dataTask.attributes['work-start']),
											:start_date => Time.parse(dataTask.attributes['work-start']),
											:estimated_hours => str_estimated_hours,
											:due_date => Time.parse(dataTask.attributes['end'])

				# assigning default status and tracker type
				i.status = DEFAULT_STATUS
				i.tracker = tracker_to_be_assign
				# for this version the author of the task is always the project manager
				i.author = User.current
				#### find_or_create_user @@projectManager, aProject, @@price_per_hour_of_projectManager , @@role_of_projectManager 
				## Recording the issue
				if (i.save)
					@@strNoticeMessage << "<b>---------Import Factory : 1 #{l(:task_has_been_created)} : '#{i.subject}'.</b><br />"
					# Update number of migrated issues
					@@migrated_issues += 1
				else
					@@strErrorMessage << "Unable to create a task !<br />"
				end
				# Manage Deliverable relation
				deliverable = Deliverable.find_by_id(deliverable_identifier)
				if deliverable.project == i.project
					deliverable.issues << i
					deliverable.save
				end
			else
				notes = ""
				journal = i.init_journal(User.current, notes)
				# updating data of the issue
				if (i.subject != encode(dataTask.attributes['name'][0, limit_for(Issue, 'subject')]) )
					i.subject = encode(dataTask.attributes['name'][0, limit_for(Issue, 'subject')])
				end
				if ( i.priority != task_priority )
					i.priority = task_priority
				end
				if (((i.start_date.yday) != Time.parse(dataTask.attributes['work-start']).yday) or ((i.start_date.year) != Time.parse(dataTask.attributes['work-start']).year))
					i.start_date = Date.parse(dataTask.attributes['work-start'])
				end
				if (i.estimated_hours != str_estimated_hours)
					i.estimated_hours = str_estimated_hours
				end
				#if (Date.parse(i.due_date.to_s()) != Date.parse(dataTask.attributes['end']))
				if (((i.due_date.yday) != Time.parse(dataTask.attributes['end']).yday) or ((i.due_date.year) != Time.parse(dataTask.attributes['end']).year))
					#@@strErrorMessage << Date.parse((Time.parse(dataTask.attributes['end'])).to_s).to_s
					#@@strErrorMessage << i.due_date.to_s()
					i.due_date = Date.parse(dataTask.attributes['end'])
				end
				i.tracker = tracker_to_be_assign
				## Recording the issue
				if (i.save)
					@@strNoticeMessage << "<b>---------Import Factory : the Task : '#{i.subject}' already exists and has been updated.</b><br />"
					# Update number of migrated issues
					@@migrated_issues += 1
					
					if !journal.new_record?
						@@strNoticeMessage << "a new record has been save in journal for task #{i.id} !<br />"
					else
						@@strNoticeMessage << "the update did not generate a record in journal for task #{i.id} !<br />"
					end
				else
					@@strErrorMessage << "Unable to update an existing task !<br />"
				end
			end
			# I save the task id
			@task_identifier = i.id
		end
	end

	def add_predecessor_task(task_identifier, task_predecessor_identifier)
		# I find the preceding issue
		issuePreceding = Issue.find_by_id(task_identifier)
		# I find the preceded issue
		issuePreceded = Issue.find_by_id(task_predecessor_identifier)
		# Creating a new relation
		if (issuePreceding and issuePreceded)
			thisRelation = IssueRelation.new({:issue_to => issuePreceding, :relation_type => "precedes"})
			thisRelation.issue_from = issuePreceded
			# Recording the relation
			if (thisRelation.save)
				@@strNoticeMessage << "<b>------------Import Factory : 1 predessor relation between Task '#{issuePreceding.id}' and Task '#{issuePreceded.id}'.</b><br />"
			else
				@@strNoticeMessage << "Unable to create a predecessor relation between Task, mainly because of an existing relation!<br />"
			end
		else
			@@strErrorMessage << "Unable to create a predecessor relation between Task because one of the two task does not exist!<br />"
		end
	end
	
	def add_assigned_user(task_identifier, nameRessource, project_identifier, role_per_group, price_per_hour)	
		# I find the good issue	
		issueAssigned = Issue.find_by_id(task_identifier)
		# I find the good project	
		projectAssigned = Project.find_by_identifier(project_identifier)
		# verifying values of the objects
		if (issueAssigned and projectAssigned)
			# Assigning issue to user
			issueAssigned.assigned_to = find_or_create_user nameRessource, projectAssigned , price_per_hour , role_per_group
			# Recording the assignation
			if (issueAssigned.save)
				@@strNoticeMessage << "<b>------------Import Factory : 1 #{l(:user)} '#{nameRessource}' assigned to Task '#{task_identifier}'.</b><br />"
			else
				@@strErrorMessage << "Unable to assign an user to Task '#{task_identifier}' !<br />"
			end
		else 
			@@strErrorMessage << "Unable to assign an user to Task '#{task_identifier}' !<br />"
		end
	end
	
	def find_or_create_user(username, project=nil, price_per_hour = nil , role_per_group = nil)
		u = User.find_by_login(username)
		if !u
			# Create a new user if not found
			mail = username[0,limit_for(User, 'mail')]
			mail = "#{mail}@internethic.com" unless mail.include?("@")
			firstname, lastname = username.split '.', 2
			if !lastname
				lastname = firstname
			end
			u = User.new :firstname => firstname[0,limit_for(User, 'firstname')].capitalize,
									 :lastname => lastname[0,limit_for(User, 'lastname')].capitalize,
									 :mail => mail.gsub(/[^-@a-z0-9\.]/i, '-')
			u.login = username[0,limit_for(User, 'login')].gsub(/[^a-z0-9_\-@\.]/i, '-')
			u.password = 'passinternethic'
			# finally, a default user is used if the new user is not valid
			## old way to save object : u = User.find(:first) unless u.save
			if (u.save)
				@@strNoticeMessage << "<b>------------Import Factory : 1 #{l(:user)} '#{username}' has been created.</b><br />"
			else
				u = User.find(:first)
				@@strErrorMessage << "Unable to create an user :  '#{username}' !<br />"
			end
		end
		# Make sure he is a member of the project
		if project 
				# assigning default role, if a role is defined then this role will be the one assigned
				role = @@DEFAULT_ROLE
				#if role_per_group
					@@allroles.each do |check_role|
						if role_per_group == check_role.name
							# assigning specific role
							role = check_role
						end
					end
				#end
			if !u.member_of?(project)
				Member.create(:user => u, :project => project)
				##, :role => role) 
				#, :rate => price_per_hour)
				rate = Rate.new(:amount => price_per_hour, :date_in_effect => Date.today.to_s, :project_id => project.id, :user_id => u.id)
				rate.save
				u.reload
			end
		end
		u
	end

	def clean_html html
		text = html.
			# normalize whitespace
			gsub(/\s+/m, ' ').
			# add in line breaks
			gsub(/<br.*?>\s*/i, "\n").
			# remove all tags
			gsub(/<.*?>/, ' ').
			# handle entities
			gsub(/&amp;/, '&').gsub(/&lt;/, '<').gsub(/&gt;/, '>').gsub(/&nbsp;/, ' ').gsub(/&quot;/, '"').
			# clean up
			squeeze(' ').gsub(/ *$/, '').strip
			# puts "cleaned html from #{html.inspect} to #{text.inspect}"
		text
	end

	# function clean_project_name ## NOT IMPLEMENTED FOR NOW
	### returns a string
	### this method returns a well formatted project name
	def clean_project_name name
		 name.
			# replace "_" by "-"
			gsub('_', '-')
		name
	end
	
	# property reader
	def get_property(data, path, property)
		# initialize string
		propertydata = ""
		# parsing properties and attributes
		data.elements.each(path) do |property_reader|
			if property_reader.attributes['name'] == property
				propertydata =  property_reader.attributes['value']
			end
		end
		propertydata
	end
	
	def get_mysettings
    	@settings = Setting.plugin_redmine_gantt_importer
 	end
  
	
	def limit_for(klass, attribute)
		klass.columns_hash[attribute.to_s].limit
	end
	
	def encoding(charset)
		@ic = Iconv.new('UTF-8', charset)
	rescue Iconv::InvalidEncoding
		return false
	end

	def encode(text)
		@ic.iconv text
	rescue
		text
	end

end

