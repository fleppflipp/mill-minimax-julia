import numpy as np

class Board:
    def __init__(self):
        self.board = np.zeros(24, dtype=int)

        self.unplaced_pieces = {1: 9, 2: 9}

        self.active_pieces = {1: 0, 2: 0}

        MILLS = [
            (0, 1, 2),
            (3, 4, 5),
            (6, 7, 8),
            (9, 10, 11),
            (12, 13, 14),
            (15, 16, 17),
            (18, 19, 20),
            (21, 22, 23),
            (0, 9, 21),
            (3, 10, 18),
            (6, 11, 15),
            (1, 4, 7),
            (16, 19, 22),
            (8, 12, 17),
            (5, 13, 20),
            (2, 14, 23),
        ]

        self.mills_dict = { i: [] for i in range(24) }
        for mill in MILLS:
            for position in mill:
                self.mills_dict[position].append(mill)

        self.adjacency_list = {
            0: [1, 9],
            1: [0, 2, 4],
            2: [1, 14],
            3: [4, 10],
            4: [1, 3, 5, 7],
            5: [4, 13],
            6: [7, 11],
            7: [4, 6, 8],
            8: [7, 12],
            9: [0, 10, 21],
            10: [3, 9, 11, 18],
            11: [6, 10, 15],
            12: [8, 13, 17],
            13: [5, 12, 14, 20],
            14: [2, 13, 23],
            15: [11, 16],
            16: [15, 17, 19],
            17: [12, 16],
            18: [10, 19],
            19: [16, 18, 20, 22],
            20: [13, 19],
            21: [9, 22],
            22: [19, 21, 23],
            23: [14, 22],
        }
        
        
    ##  validating moves in each phase of the game
    ## the player parameter is a number, indicationg which players move it is, 1 or 2
    
    def is_valid_first_phase(self, position):
        if(position < 0 or position > 23):
            return False
        
        if(self.board[position] != 0): 
            return False
        
        return True
    
    def is_valid_second_phase(self, start_pos, end_pos, player):
        if (start_pos < 0 or start_pos > 23) or (end_pos < 0 or end_pos > 23):
            return False
        
        if (self.board[start_pos] != player):
            return False
        
        if (self.board[end_pos] != 0 ):
            return False
        
        if(end_pos not in self.adjacency_list[start_pos]):
            return False
        return True

    def is_valild_third_phase(self, start_pos, end_pos, player):
        if (start_pos < 0 or start_pos > 23) or (end_pos < 0 or end_pos > 23):
            return False
        if (self.board[start_pos] != player):
            return False
        if (self.board[end_pos] != 0 ):
            return False
        return True
    
    def is_mill_after_move(self, position, player):
        for p1, p2, p3 in self.mills_dict[position]:
            if(self.board[p1] == player and self.board[p2] == player and self.board[p3] == player):
                return True
        return False
    
    # Methods returning all the available actions regarding the current state
    def available_actions_first_phase(self):
        return [pos for pos in range(len(self.board)) if self.board[pos] == 0]

    def available_actions_second_phase(self, pos):
        return [neigh for neigh in self.adjacency_list[pos] if self.board[neigh] == 0]