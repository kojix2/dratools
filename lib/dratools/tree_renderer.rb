# frozen_string_literal: true

module Dratools
  # Renders a TraversalNode tree as terminal-friendly text.
  class TreeRenderer
    DEFAULT_SUMMARY_THRESHOLD = 5

    def initialize(file_type: DdbjRecordFields::FILE_TYPE_SRA,
                   summary_threshold: DEFAULT_SUMMARY_THRESHOLD)
      @file_type = file_type
      @summary_threshold = summary_threshold
    end

    def render(root)
      lines = [label_for(root)]
      render_children(root.children, prefix: '', lines: lines)
      lines.join("\n")
    end

    private

    def render_children(children, prefix:, lines:)
      display_children = summarized_children(children)
      display_children.each_with_index do |child, index|
        last = index == display_children.length - 1
        connector = last ? '└─ ' : '├─ '
        lines << "#{prefix}#{connector}#{label_for(child)}"
        next if child.children.empty?

        child_prefix = "#{prefix}#{last ? '   ' : '│  '}"
        render_children(child.children, prefix: child_prefix, lines: lines)
      end
    end

    def summarized_children(children)
      return children unless summarizable_run_group?(children)

      [
        TraversalNode.new(
          type: DdbjRecordFields::SRA_RUN_RESOURCE_TYPE,
          accession: "#{children.length} records",
          children: [
            TraversalNode.new(
              type: summary_leaf_label(children)
            )
          ]
        )
      ]
    end

    def summary_leaf_label(children)
      return "#{@file_type} downloads not expanded" if children.any? { |child| child.record.nil? }

      "no #{@file_type} downloads"
    end

    def summarizable_run_group?(children)
      return false if children.length <= @summary_threshold
      return false unless children.all?(&:run?)

      children.all? { |child| child.downloads.empty? && child.errors.empty? }
    end

    def label_for(node)
      return [node.type, node.url].compact.join(' ') if node.download?

      label_parts = []
      label_parts << relation_label(node)
      label_parts << node.type unless node.relation == TraversalNode::CHILD_BIOPROJECT_RELATION
      label_parts << node.accession
      label_parts << node.object_type
      label_parts << "error: #{node.error}" if node.errored?
      label_parts.compact.join(' ')
    end

    def relation_label(node)
      case node.relation
      when TraversalNode::CHILD_BIOPROJECT_RELATION
        'childBioProject'
      end
    end
  end
end
