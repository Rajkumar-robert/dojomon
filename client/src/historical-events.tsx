import { ParsedEntity, SDK } from "@dojoengine/sdk";
import { useAccount } from "@starknet-react/core";
import { SchemaType } from "./typescript/models.gen";
import { AccountInterface, addAddressPadding } from "starknet";
import { useEffect, useState } from "react";
import { Subscription } from "@dojoengine/torii-client";

export function HistoricalEvents({ sdk }: { sdk: SDK<SchemaType> }) {
  const { account } = useAccount();
  const [events, setEvents] = useState<ParsedEntity<SchemaType>[][]>([]);
  const [subscription, setSubscription] = useState<Subscription | null>(null);

  useEffect(() => {
    async function getHistoricalEvents(account: AccountInterface) {
      try {
        const e = await sdk.getEventMessages({
          // query: {
          //   event_messages_historical: {
          //     Moved: {
          //       $: { where: { player: { $eq: addAddressPadding(account.address) } } }
          //     }
          //   }
          // },
          query: { entityIds: [addAddressPadding(account.address)] },
          callback: () => {},
          historical: true,
        });
        // @ts-expect-error FIX: type here
        setEvents(e);
      } catch (error) {
        setEvents([]);
        console.error(error);
      }
    }

    if (account) {
      getHistoricalEvents(account);
    }
  }, [account, setEvents, sdk]);

  useEffect(() => {
    async function subscribeHistoricalEvent(account: AccountInterface) {
      try {
        const s = await sdk.subscribeEventQuery({
          // query: {
          //   event_messages_historical: {
          //     Moved: {
          //       $: { where: { player: { $eq: addAddressPadding(account.address) } } }
          //     }
          //   }
          // },
          query: { entityIds: [addAddressPadding(account.address)] },
          callback: ({ data, error }) => {
            console.log(data, error);
          },
          historical: true,
        });
        setSubscription(s);
      } catch (error) {
        setEvents([]);
        if (subscription) {
          subscription.free();
        }
        console.error(error);
      }
    }

    if (account) {
      subscribeHistoricalEvent(account);
    }
  }, [account, setEvents]);

  if (!account) {
    return (
      <div className="mt-6">
        <h2 className="text-white">Please connect your wallet</h2>
      </div>
    );
  }
  return (
    <div className="mt-6">
      <h2 className="text-white">Player Events :</h2>
      {events.map((e: ParsedEntity<SchemaType>[], key) => {
        return <Event event={e[0]} key={key} />;
      })}
    </div>
  );
}
function Event({ event }: { event: ParsedEntity<SchemaType> }) {
  if (!event) return null;
  const player = event.models?.dojomon?.PlayerStats?.player;
  const gold = event.models?.dojomon?.PlayerStats?.gold;

  return (
    <div className="text-white flex gap-3">
      <div>{event.entityId.toString()}</div>
      <div>
        <div>Player: {player}</div>
        <div>Gold: {gold?.toString()}</div>
      </div>
    </div>
  );
}
