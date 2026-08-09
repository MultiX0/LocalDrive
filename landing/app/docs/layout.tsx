import { Sidebar, type SidebarSection } from "@/components/docs/Sidebar";
import { getNav, hrefFor } from "@/lib/docs/source";

export default async function DocsLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const nav = await getNav();

  const sections: SidebarSection[] = nav.map((section) => ({
    key: section.key || "root",
    label: section.label,
    items: section.docs.map((doc) => ({
      slug: doc.slug,
      title: doc.title,
      href: hrefFor(doc.slug),
    })),
  }));

  return (
    <div className="mx-auto max-w-7xl px-5 sm:px-7 lg:px-8">
      <div className="lg:grid lg:grid-cols-[220px_minmax(0,1fr)] lg:gap-12 xl:grid-cols-[220px_minmax(0,1fr)_200px]">
        {/* the rail scrolls independently, so a long section does not drag the
            page position with it */}
        <aside className="py-6 lg:sticky lg:top-16 lg:max-h-[calc(100dvh-4rem)] lg:overflow-y-auto lg:py-10">
          <Sidebar sections={sections} />
        </aside>
        {children}
      </div>
    </div>
  );
}
