! A binding of an implements block and a generic binding of the same name
! (DI extension E6). A call of the name on the type selects, among the
! specifics of the type's generic binding and the bindings of its
! implements blocks, the one that accepts the reference; a call through a
! trait object or a generic parameter that the trait constrains calls the
! implements-block binding. The generic binding's specifics may be generic
! procedures. A non-generic message may also be implemented by a specific
! of the type's generic binding, also one that an extension overrides, in
! another module.
! GFortran does not accept this LFortran extension.
module traits_generic_overload_04_base
    implicit none
    private
    public :: Base

    type :: Base
        integer :: id = 3
    contains
        generic   :: serve => serve_n, serve0
        procedure :: serve0, serve_n
    end type Base

contains

    integer function serve0(self)
        class(Base), intent(in) :: self
        serve0 = self%id
    end function serve0

    integer function serve_n(self, n)
        class(Base), intent(in) :: self
        integer, intent(in) :: n
        serve_n = self%id * n
    end function serve_n

end module traits_generic_overload_04_base

module traits_generic_overload_04_m
    use traits_generic_overload_04_base, only: Base
    implicit none
    private
    public :: IClient, IStore, Client, Store, Child, use_obj, use_gen, &
        use_store, put_count

    abstract interface :: IClient
        integer function serve(self)
            type(itself), intent(in), pass :: self
        end function serve
    end interface IClient

    abstract interface :: IStore
        integer function put(self)
            type(itself), intent(in), pass :: self
        end function put
    end interface IStore

    ! The generic binding `serve` has one non-generic specific.
    type :: Client
        integer :: id = 3
    contains
        generic   :: serve => serve_n
        procedure :: serve_n
    end type Client

    ! The generic binding `put` has a generic specific.
    type :: Store
        integer :: n = 5
    contains
        generic   :: put => put_one
        procedure :: put_one
    end type Store

    ! The non-generic message `serve` is implemented by an inherited
    ! specific of a generic binding, overridden.
    type, extends(Base), implements(IClient) :: Child
    contains
        procedure :: serve0 => child_serve0
    end type Child

    implements IClient :: Client
        procedure :: serve => other
    end implements

    implements IStore :: Store
        procedure :: put => put_none
    end implements

contains

    integer function other(self)
        class(Client), intent(in) :: self
        other = 42
    end function other

    integer function serve_n(self, n)
        class(Client), intent(in) :: self
        integer, intent(in) :: n
        serve_n = self%id * n
    end function serve_n

    integer function put_none(self)
        class(Store), intent(in) :: self
        put_none = -self%n
    end function put_none

    integer function put_one{T}(self, x)
        class(Store), intent(in) :: self
        type(T), intent(in) :: x
        put_one = self%n + 1
    end function put_one

    integer function child_serve0(self)
        class(Child), intent(in) :: self
        child_serve0 = 100 + self%id
    end function child_serve0

    integer function use_obj(a)
        class(IClient), intent(in) :: a
        use_obj = a%serve()
    end function use_obj

    integer function use_gen{IClient :: C}(x)
        type(C), intent(in) :: x
        use_gen = x%serve()
    end function use_gen

    integer function use_store{IStore :: S}(x)
        type(S), intent(in) :: x
        use_store = x%put()
    end function use_store

    integer function put_count(s)
        type(Store), intent(in) :: s
        put_count = s%put() + s%put(1.0)
    end function put_count

end module traits_generic_overload_04_m

program traits_generic_overload_04
    use traits_generic_overload_04_m
    implicit none
    type(Client) :: c
    type(Store) :: s
    type(Child) :: d

    if (c%serve() /= 42) error stop 1
    if (c%serve(2) /= 6) error stop 2
    if (use_gen(c) /= 42) error stop 3
    if (use_obj(c) /= 42) error stop 4

    if (s%put() /= -5) error stop 5
    if (s%put(7) /= 6) error stop 6
    if (use_store(s) /= -5) error stop 7
    if (put_count(s) /= 1) error stop 8

    if (d%serve() /= 103) error stop 9
    if (d%serve(2) /= 6) error stop 10
    if (use_obj(d) /= 103) error stop 11
    if (use_gen(d) /= 103) error stop 12
    print *, c%serve(), c%serve(2), s%put(), s%put(7), d%serve()
end program traits_generic_overload_04
