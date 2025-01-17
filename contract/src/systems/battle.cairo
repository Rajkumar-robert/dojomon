use dojomon::models::{
    PlayerStats,
    ReceiverFriendRequest, Dojomon, DojomonType, MoveEffect, Move, Lobby
};
use dojomon::events::{PlayerAttacked};
use dojomon::utils::random::{Random, RandomImpl, RandomTrait};
use starknet::{ContractAddress, get_caller_address};

// Define the interface
#[starknet::interface]
trait IBattle<T> {
    fn attack(
        ref self: T,
        lobby_code: u32,
        attacker_dojomon_id: u32,
        defender_dojomon_id: u32,
        move_id: u32,
    );
    fn changeTurn(
        ref self: T,
        lobby_code: u32
    );
}

// Dojo contract
#[dojo::contract]
pub mod battle {
    
    use super::{
            IBattle, PlayerStats, ReceiverFriendRequest, Dojomon, DojomonType, MoveEffect, Move, Lobby , Random, RandomImpl, RandomTrait, PlayerAttacked
        };
        use starknet::{ContractAddress, get_caller_address};
        use dojo::model::{ModelStorage, ModelValueStorage};
        use dojo::event::EventStorage;

    #[abi(embed_v0)]
    impl BattleImpl of IBattle<ContractState> {
        
        fn attack(
            ref self: ContractState,
            lobby_code: u32,
            attacker_dojomon_id: u32,
            defender_dojomon_id: u32,
            move_id: u32,
        ) {
            let mut world = self.world_default();

            // Retrieve attacker and defender Dojomons
            let mut attacker_dojomon: Dojomon = world.read_model(attacker_dojomon_id);
            let mut defender_dojomon: Dojomon = world.read_model(defender_dojomon_id);

            // Retrieve the selected move
            let selected_move: Move = world.read_model(move_id);

            // Critical hit chance (10%)
            let mut randomizer = RandomImpl::new('world');
            let is_critical = randomizer.between::<u32>(1, 100) <= 10; // Generates 1 if critical hit
            let critical_multiplier = if is_critical { 150 } else { 100 }; // 150% for critical, scaled by 100

            // Base damage calculation (scaled by 100 for precision)
            let base_damage = selected_move.power * attacker_dojomon.attack * critical_multiplier / (defender_dojomon.defense * 100);

            println!("Base damage: {}", base_damage);

            // Apply type effectiveness (scaled by 100 for precision)
            let type_effectiveness = self.calculate_type_effectiveness(selected_move.move_type, defender_dojomon.dojomon_type);

            let rand_variation = randomizer.between::<u32>(attacker_dojomon.level,attacker_dojomon.level+10);
            let adding_damage_percent = 10 * type_effectiveness + rand_variation;
            
            
            let final_damage = base_damage + ( base_damage * adding_damage_percent / 100 );

            // Update defender's health
            if defender_dojomon.health <= final_damage {
                defender_dojomon.health = 0;
            } else {
                defender_dojomon.health -= final_damage;
            }

            println!("Final damage dealt: {}", final_damage);

            if is_critical {
                println!("It was a critical hit!");
            }

            // Apply move effects
            self.apply_move_effect(selected_move.effect, ref defender_dojomon);

            // Update models in the world
            world.write_model(@attacker_dojomon);
            world.write_model(@defender_dojomon);

            // Emit an event for the attack
            world.emit_event(@PlayerAttacked {
                attacker_dojomon: world.read_model(attacker_dojomon_id),
                defender_dojomon: world.read_model(defender_dojomon_id),
                move: selected_move,
                lobby: world.read_model(lobby_code),
            });

            // Switch the turn
            self.changeTurn(lobby_code);
        }

        fn changeTurn(
            ref self: ContractState,
            lobby_code: u32
        ){
            let mut world = self.world_default();
            let player = get_caller_address();
            let mut lobby: Lobby = world.read_model(lobby_code);

            if lobby.host_player == player {
                lobby.turn = lobby.guest_player;
            } else {
                lobby.turn = lobby.host_player;
            }

            world.write_model(@lobby);
        }
    }

    /// Internal trait implementation for helper functions
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Returns the default world storage for the contract.
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"dojomon")
        }

        fn calculate_type_effectiveness(ref self: ContractState, move_type: DojomonType, target_type: DojomonType) -> u32 {
            match (move_type, target_type) {
                (DojomonType::Fire, DojomonType::Grass) => 2_u32,
                (DojomonType::Fire, DojomonType::Water) => 1_u32,
                (DojomonType::Fire, DojomonType::Ice) => 2_u32,

                (DojomonType::Water, DojomonType::Fire) => 2_u32,
                (DojomonType::Water, DojomonType::Electric) => 1_u32,
                (DojomonType::Water, DojomonType::Grass) => 1_u32,

                (DojomonType::Electric, DojomonType::Water) => 2_u32,
                (DojomonType::Electric, DojomonType::Grass) => 1_u32,
                (DojomonType::Electric, DojomonType::Electric) => 1_u32,

                (DojomonType::Grass, DojomonType::Water) => 2_u32,
                (DojomonType::Grass, DojomonType::Fire) => 1_u32,
                (DojomonType::Grass, DojomonType::Grass) => 1_u32,

                (DojomonType::Ice, DojomonType::Grass) => 2_u32,
                (DojomonType::Ice, DojomonType::Fire) => 1_u32,
                (DojomonType::Ice, DojomonType::Water) => 1_u32,

                (DojomonType::Psychic, DojomonType::Poison) => 2_u32,
                (DojomonType::Psychic, DojomonType::Psychic) => 1_u32,

                (DojomonType::Normal, DojomonType::Ghost) => 0_u32,

                (DojomonType::Ghost, DojomonType::Normal) => 0_u32,
                
                _ => 1_u32,
            }
        }

        fn apply_move_effect(ref self: ContractState, effect: MoveEffect, ref defender: Dojomon) {
            match effect {
                MoveEffect::Burn => {
                    defender.health -= 5; // Burn deals 5 damage per turn
                    defender.attack -= 5; // Burn reduces attack by half
                },
                MoveEffect::Paralyze => {
                    defender.speed /= 2; // Paralysis halves speed
                    // Add logic for a chance to skip a turn due to paralysis
                },
                MoveEffect::Freeze => {
                    defender.speed = 0; // Frozen Pokémon can't move
                    // Add logic to handle thawing out after a few turns
                },
                MoveEffect::Confuse => {
                    // Add logic to track confusion status and calculate chances of hitting self
                },
                MoveEffect::Flinch => {
                    // Add logic to skip the next turn if the Pokémon flinches
                },
                MoveEffect::LowerSpecialDefense => {
                    if defender.defense > 5 {
                        defender.defense -= 5; // Lower special defense by a fixed amount
                    }
                },
                _ => {
                    // No effect for unrecognized effect strings
                }
            }
        }
    }

}