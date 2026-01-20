import { createFileRoute, Link, Outlet, useMatches, useNavigate } from '@tanstack/react-router'
import { supabase } from '@/db'
import {
  Pagination,
  PaginationContent,
  PaginationItem,
  PaginationLink,
  PaginationFirst,
  PaginationPrevious,
  PaginationNext,
  PaginationLast,
  PaginationEllipsis,
} from '@/components/ui/pagination'

const PAGE_SIZE = 50

export const Route = createFileRoute('/climbs')({
  component: ClimbsLayout,
  validateSearch: (search: Record<string, unknown>) => ({
    page: Number(search.page) || 1,
  }),
  loaderDeps: ({ search }) => ({ page: search.page }),
  loader: async ({ deps }) => {
    const page = deps.page
    const offset = (page - 1) * PAGE_SIZE

    // Get total count
    const { count } = await supabase
      .from('climbs')
      .select('*', { count: 'exact', head: true })

    // Get paginated climbs
    const { data: climbs, error } = await supabase
      .from('climbs')
      .select('id, name, grade_yds, grade_vscale, is_sport, is_trad, is_boulder, areas(name, path_tokens)')
      .order('name')
      .range(offset, offset + PAGE_SIZE - 1)

    if (error) throw error

    return {
      climbs: climbs || [],
      totalCount: count || 0,
      page,
      totalPages: Math.ceil((count || 0) / PAGE_SIZE),
    }
  },
})

function ClimbsLayout() {
  const { climbs, totalCount, page, totalPages } = Route.useLoaderData()
  const matches = useMatches()
  const navigate = useNavigate()

  const hasChildRoute = matches.some(m => m.id.includes('$id'))

  if (hasChildRoute) {
    return <Outlet />
  }

  return (
    <div className="px-4 py-8 max-w-5xl mx-auto">
      <h1 className="mb-2">All Climbs</h1>
      <p className="text-neutral-500 mb-6">{totalCount.toLocaleString()} climbs total</p>

      {/* Pagination controls */}
      <ClimbsPagination page={page} totalPages={totalPages} navigate={navigate} />

      <div className="grid gap-0 border-t border-neutral-200">
        {climbs.map((climb) => (
          <Link
            key={climb.id}
            to="/climbs/$id"
            params={{ id: climb.id }}
            className="flex justify-between items-center py-3 px-4 border-b border-neutral-200 hover:bg-neutral-50 no-underline"
          >
            <div>
              <div className="font-medium">{climb.name}</div>
              {climb.areas && (
                <div className="text-neutral-500 text-sm">
                  {climb.areas.path_tokens?.slice(0, 3).join(' › ')}
                </div>
              )}
            </div>
            <div className="flex gap-3 items-center text-sm">
              {climb.grade_yds && <span className="text-neutral-600">{climb.grade_yds}</span>}
              {climb.grade_vscale && <span className="text-neutral-600">{climb.grade_vscale}</span>}
              {climb.is_sport && <span className="text-xs px-2 py-0.5 rounded bg-emerald-100 text-emerald-700">sport</span>}
              {climb.is_trad && <span className="text-xs px-2 py-0.5 rounded bg-amber-100 text-amber-700">trad</span>}
              {climb.is_boulder && <span className="text-xs px-2 py-0.5 rounded bg-violet-100 text-violet-700">boulder</span>}
            </div>
          </Link>
        ))}
      </div>

      {/* Bottom pagination */}
      <ClimbsPagination page={page} totalPages={totalPages} navigate={navigate} />
    </div>
  )
}

function ClimbsPagination({ page, totalPages, navigate }: { page: number; totalPages: number; navigate: any }) {
  // Generate page numbers to show
  const getPageNumbers = () => {
    const pages: (number | string)[] = []

    if (totalPages <= 7) {
      for (let i = 1; i <= totalPages; i++) pages.push(i)
    } else {
      pages.push(1)
      if (page > 3) pages.push('...')
      for (let i = Math.max(2, page - 1); i <= Math.min(totalPages - 1, page + 1); i++) {
        pages.push(i)
      }
      if (page < totalPages - 2) pages.push('...')
      pages.push(totalPages)
    }
    return pages
  }

  return (
    <Pagination className="my-6">
      <PaginationContent>
        <PaginationItem>
          <PaginationFirst
            onClick={() => page > 1 && navigate({ search: { page: 1 } })}
            className={page <= 1 ? 'pointer-events-none opacity-50' : ''}
          />
        </PaginationItem>
        <PaginationItem>
          <PaginationPrevious
            onClick={() => page > 1 && navigate({ search: { page: page - 1 } })}
            className={page <= 1 ? 'pointer-events-none opacity-50' : ''}
          />
        </PaginationItem>

        {getPageNumbers().map((p, i) => (
          <PaginationItem key={`page-${i}`}>
            {p === '...' ? (
              <PaginationEllipsis />
            ) : (
              <PaginationLink
                onClick={() => navigate({ search: { page: p } })}
                isActive={p === page}
              >
                {p}
              </PaginationLink>
            )}
          </PaginationItem>
        ))}

        <PaginationItem>
          <PaginationNext
            onClick={() => page < totalPages && navigate({ search: { page: page + 1 } })}
            className={page >= totalPages ? 'pointer-events-none opacity-50' : ''}
          />
        </PaginationItem>
        <PaginationItem>
          <PaginationLast
            onClick={() => page < totalPages && navigate({ search: { page: totalPages } })}
            className={page >= totalPages ? 'pointer-events-none opacity-50' : ''}
          />
        </PaginationItem>
      </PaginationContent>
    </Pagination>
  )
}
