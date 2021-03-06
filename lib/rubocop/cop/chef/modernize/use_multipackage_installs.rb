# frozen_string_literal: true
#
# Copyright:: 2020, Chef Software, Inc.
# Author:: Tim Smith (<tsmith@chef.io>)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
module RuboCop
  module Cop
    module Chef
      module ChefModernize
        # Pass an array of packages to package resources instead of iterating over an array of packages when using multi-package capable package subsystem such as apt, yum, chocolatey, dnf, or zypper. Multi-package installs are faster and simplify logs.
        #
        # @example
        #
        #   # bad
        #   %w(bmon htop vim curl).each do |pkg|
        #     package pkg do
        #       action :install
        #     end
        #   end
        #
        #   # good
        #   package %w(bmon htop vim curl)
        #
        class UseMultipackageInstalls < Base
          extend AutoCorrector

          MSG = 'Pass an array of packages to package resources instead of iterating over an array of packages when using multi-package capable package subsystem such as apt, yum, chocolatey, dnf, or zypper. Multi-package installs are faster and simplify logs.'
          MULTIPACKAGE_PLATS = %w(debian redhat suse amazon fedora scientific oracle rhel ubuntu centos redhat).freeze

          def_node_matcher :platform_or_platform_family?, <<-PATTERN
            (send (send nil? :node) :[] (str {"platform" "platform_family"}) )
          PATTERN

          def_node_matcher :platform_helper?, <<-PATTERN
          (if
            (send nil? {:platform_family? :platform?} $... )
            $(block
              (send
                $(array ... ) :each)
              (args ... )
              {(block
                (send nil? :package
                  (lvar ... ))
                (args)
                (send nil? :action
                  (sym :install)))
                (send nil? :package
                    (lvar _))}) nil?)
          PATTERN

          def_node_matcher :package_array_install?, <<-PATTERN
          (block
            (send
              $(array ... ) :each)
            (args ... )
            {(block
              (send nil? :package
                (lvar ... ))
              (args)
              (send nil? :action
                (sym :install)))
              (send nil? :package
                  (lvar _))})
          PATTERN

          # see if all platforms in the when condition are multi-package compliant
          def multipackage_platforms?(condition_obj)
            condition_obj.all? do |p|
              MULTIPACKAGE_PLATS.include?(p.value)
            end
          end

          def on_when(node)
            return unless platform_or_platform_family?(node.parent.condition) &&
                          package_array_install?(node.body) &&
                          multipackage_platforms?(node.conditions)
            check_offense(node.body)
          end

          def on_if(node)
            platform_helper?(node) do |plats, blk, _pkgs|
              check_offense(blk) if multipackage_platforms?(plats)
            end
          end

          def check_offense(node)
            add_offense(node, message: MSG, severity: :refactor) do |corrector|
              package_array_install?(node) do |vals|
                corrector.replace(node, "package #{vals.source}")
              end
            end
          end
        end
      end
    end
  end
end
