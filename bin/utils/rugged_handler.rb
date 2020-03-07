module RuggedHandler

  # Recursively get information from all files given a rugged Git tree
  def lslr(tree, path = '')
    all_files = []
    for f in tree.map { |x| x }
      f[:path] = path + '/' + f[:name]
      if f[:type] == :tree
        begin
          all_files << lslr(git.lookup(f[:oid]), f[:path])
        rescue StandardError => e
          log e
          all_files
        end
      else
        all_files << f
      end
    end
    all_files.flatten
  end


  def ls_tree(tree)
    # first level files and first level directories
    all_fs = []
    for f in tree.map {|x| x}
      f[:path] = '/' + f[:name]
      all_fs << f
    end
  end

end