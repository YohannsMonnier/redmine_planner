# redMine - project management software
# Copyright (C) 2008 Peter Van den Bosch
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

require 'redmine'

RAILS_DEFAULT_LOGGER.info 'Starting Gantt Importer plugin for RedMine'

Redmine::Plugin.register :redmine_gantt_importer do
  name 'Redmine Gantt Planner plugin'
  author 'Yohann Monnier - Internethic'
  description 'Project Importer/Exporter for planner files'
  version '0.0.4'
  menu :top_menu, :gantt_planner, { :controller => 'gantt_planner', :action => 'index' }, :if => Proc.new {User.current.admin?}, :caption => 'Importer' 
  permission :import_planner_file, {:gantt_importer => [:index, :import]}
  settings:default => {
    'importer_role_id' => 1,
    'importer_tracker_id' => 1,
    'importer_priority_id' => 1
  }, :partial => 'settings/gantt_planner_settings'
end


