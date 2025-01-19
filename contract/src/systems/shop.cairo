use dojomon::models::{
    PlayerStats,DojoBallType

};
use starknet::{ContractAddress, get_caller_address};

// Define the interface
#[starknet::interface]
trait IShop<T> {
    fn buyDojoBall( ref self: T, dojoball_type: DojoBallType, quantity: u32);
}

// Dojo contract
#[dojo::contract]
pub mod shop {
    
    use super::{
            IShop, PlayerStats, DojoBallType
        };
        use starknet::{ContractAddress, get_caller_address};
        use dojo::model::{ModelStorage, ModelValueStorage};
        use dojo::event::EventStorage;

    #[abi(embed_v0)]
    impl ShopImpl of IShop<ContractState> {
        
        fn buyDojoBall( ref self: ContractState,  dojoball_type: DojoBallType, quantity: u32) { 
            let mut world = self.world_default();
            let player = get_caller_address();

            let mut counter : Counter = world.read_model(COUNTER_ID);
            
            let mut dojoball_count = counter.dojoball_count;

            //incrementing the counter
            counter.dojoball_count += quantity;
            world.write_model(@counter);

            

            //mapping dojoball type to gold expense
            let gold_expense = match dojoball_type {
                DojoBallType::Dojoball => DOJOBALL_PRICE,
                DojoBallType::Greatball => GREATBALL_PRICE,
                DojoBallType::Ultraball => ULTRABALL_PRICE,
                DojoBallType::Masterball => MASTERBALL_PRICE,
            };

            // Deduct gold from player
            let mut player_stats: PlayerStats = world.read_model(player);
            player_stats.gold -= gold_expense * quantity;
            world.write_model(@player_stats);


            
            }

        }
        

    /// Internal trait implementation for helper functions
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Returns the default world storage for the contract.
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"dojomon")
        }
    }

}