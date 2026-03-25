from mill_board import Board
from copy import deepcopy

class MCTSNode:
    def __init__(self, state, player, parent=None):
        self.state = state
        self.player = player
        self.parent = parent
        
        if self.state.unplaced_pieces[player] != 0 or self.state.active_pieces[player] == 3:
            self.action = self.state.available_actions_first_phase()
        else:
            self.action = self.state.available_actions_second_phase()

        self.children = []
        self.visits = 0
        self.wins = 0.0
        self.untried_actions = self.action
