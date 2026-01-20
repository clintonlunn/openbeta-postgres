import { createFileRoute, Link } from '@tanstack/react-router'
import { supabase } from '@/db'

export const Route = createFileRoute('/')({
  component: HomePage,
  loader: async () => {
    // Count total climbs
    const { count: total_climbs } = await supabase
      .from('climbs')
      .select('*', { count: 'exact', head: true })

    // Count countries (top-level areas with no parent)
    const { count: countries } = await supabase
      .from('areas')
      .select('*', { count: 'exact', head: true })
      .is('parent_id', null)

    return { total_climbs: total_climbs || 0, countries: countries || 0 }
  },
})

function HomePage() {
  const { total_climbs, countries } = Route.useLoaderData()

  return (
    <div className="px-4 py-16 max-w-3xl mx-auto">
      <h1 className="text-5xl mb-4">OpenBeta</h1>
      <p className="text-neutral-500 text-lg mb-12">Free and open climbing route database</p>

      <div className="grid grid-cols-2 gap-8 mb-12">
        <div>
          <div className="text-4xl font-light mb-1">{total_climbs.toLocaleString()}</div>
          <div className="text-neutral-500">Climbs</div>
        </div>
        <div>
          <div className="text-4xl font-light mb-1">{countries}</div>
          <div className="text-neutral-500">Countries</div>
        </div>
      </div>

      <div className="space-y-4">
        <Link
          to="/areas"
          className="block p-6 border border-neutral-200 rounded-lg hover:border-neutral-400 no-underline"
        >
          <div className="font-medium mb-1">Browse by Area</div>
          <div className="text-neutral-500 text-sm">Explore climbs by country, state, and region</div>
        </Link>

        <Link
          to="/climbs"
          className="block p-6 border border-neutral-200 rounded-lg hover:border-neutral-400 no-underline"
        >
          <div className="font-medium mb-1">All Climbs</div>
          <div className="text-neutral-500 text-sm">Browse the full database</div>
        </Link>
      </div>
    </div>
  )
}
