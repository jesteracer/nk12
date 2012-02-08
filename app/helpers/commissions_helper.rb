module CommissionsHelper

#  def uik_votes(uik, index)
#    uik.votings.find_by_voting_dictionary_id(index).votes
    #uik.votings[index].votes
#  end

  def vote_class(c, p, index)
    if c.state[:uik][index-1] ==  p.votings[index-1]
      'green'
    else
      'red'
    end
  end

  def vote_class_uik(commission, index)
    #СДЕЛАТЬ Оптимизировать
    return 'gray' unless commission.votes_taken
    if commission.state[:checked] and commission.state[:uik][index-1] ==  commission.state[:checked][index-1]
      'green'
    else
      'red'
    end
  end

  def vote_color_uik(commission, index)
    #СДЕЛАТЬ Оптимизировать
    return 'gray' unless commission.votes_taken
    if commission.state[:checked] and commission.state[:uik][index-1] ==  commission.state[:checked][index-1]
      'green'
    else
      'red'
    end
  end

end
